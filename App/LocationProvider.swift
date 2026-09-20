import CoreLocation
import Combine

// A small interface lets tests exercise permission and retry behavior without GPS.
@MainActor
protocol LocationManaging: AnyObject {
    var delegate: CLLocationManagerDelegate? { get set }
    var desiredAccuracy: CLLocationAccuracy { get set }
    var distanceFilter: CLLocationDistance { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    var accuracyAuthorization: CLAccuracyAuthorization { get }
    var location: CLLocation? { get }
    func requestWhenInUseAuthorization()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

extension CLLocationManager: LocationManaging {}

@MainActor
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var message = "等待定位授权"
    @Published private(set) var permission = "尚未检查"
    @Published private(set) var accuracy = "N/A"
    @Published private(set) var lastError = "无"
    private let manager: LocationManaging
    private let now: () -> Date
    private var enabled = false
    private var updating = false
    private var askedPermission = false
    private var lastStart = Date.distantPast

    #if targetEnvironment(simulator)
    let environment = "iOS 模拟器"
    #else
    let environment = "iPhone 真机"
    #endif

    init(manager: LocationManaging, now: @escaping () -> Date = Date.init) {
        self.manager = manager
        self.now = now
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = kCLDistanceFilterNone
    }

    convenience override init() { self.init(manager: CLLocationManager()) }

    var currentLocation: CLLocation? {
        guard let location, Self.isUsable(location, at: now()) else { return nil }
        return location
    }

    static func isUsable(_ point: CLLocation, at now: Date) -> Bool {
        let age = now.timeIntervalSince(point.timestamp)
        return point.horizontalAccuracy >= 0 && point.horizontalAccuracy.isFinite
            && CLLocationCoordinate2DIsValid(point.coordinate) && (-5...120).contains(age)
    }

    func start() {
        enabled = true
        applyAuthorization()
    }

    func stop() {
        enabled = false
        stopStream()
    }

    private func stopStream() {
        if updating { manager.stopUpdatingLocation() }
        updating = false
    }

    private func applyAuthorization() {
        accuracy = manager.accuracyAuthorization == .reducedAccuracy ? "大致位置" : "精确位置"
        switch manager.authorizationStatus {
        case .notDetermined:
            permission = "尚未授权"
            message = "请允许使用位置"
            if enabled && !askedPermission {
                askedPermission = true
                manager.requestWhenInUseAuthorization()
            }
        case .authorizedAlways, .authorizedWhenInUse:
            permission = manager.authorizationStatus == .authorizedAlways ? "始终允许" : "使用期间允许"
            guard enabled else { return }
            if let cached = manager.location, Self.isUsable(cached, at: now()) { location = cached }
            message = currentLocation == nil ? waitingMessage : "已定位"
            if !updating { beginStream() }
        case .denied, .restricted:
            stopStream()
            location = nil
            permission = manager.authorizationStatus == .restricted ? "系统限制" : "定位被拒绝"
            message = "请检查系统定位服务及 SkyPlate 的位置权限"
        @unknown default:
            stopStream()
            location = nil
            permission = "未知权限"
            message = "定位权限状态未知，请重新打开 App"
        }
    }

    private var waitingMessage: String {
        #if targetEnvironment(simulator)
        return "等待模拟位置：在模拟器 Features → Location 中选择位置"
        #else
        return "权限已允许，正在获取位置…可在靠窗或室外稍等"
        #endif
    }

    private func beginStream() {
        lastStart = now()
        updating = true
        // Use continuous updates only; do not mix requestLocation() with this stream.
        manager.startUpdatingLocation()
    }

    func retry() {
        guard enabled else { return }
        lastError = "无"
        stopStream()
        applyAuthorization()
    }

    func renewIfNeeded() {
        guard enabled,
              manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse else { return }
        // A stationary phone may receive fewer updates. Restart only after 60s
        // without a fresh position, and at most once every 30s.
        let age = location.map { now().timeIntervalSince($0.timestamp) } ?? .infinity
        guard age > 60, now().timeIntervalSince(lastStart) >= 30 else { return }
        stopStream()
        message = waitingMessage
        beginStream()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        applyAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        receive(locations)
    }

    func receive(_ locations: [CLLocation]) {
        guard enabled,
              manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse,
              let point = locations.filter({ Self.isUsable($0, at: now()) }).max(by: { $0.timestamp < $1.timestamp }) else { return }
        location = point
        lastError = "无"
        message = manager.accuracyAuthorization == .reducedAccuracy ? "已定位（大致位置，最近飞机可能有偏差）" : "已定位"
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        receive(error)
    }

    func receive(_ error: Error) {
        guard enabled else { return }
        let e = error as NSError
        lastError = "\(e.domain) / \(e.code)"
        if e.domain == kCLErrorDomain && e.code == CLError.locationUnknown.rawValue {
            // locationUnknown is temporary. Keep listening instead of claiming
            // permission is disabled or discarding a still-valid recent fix.
            message = currentLocation == nil ? waitingMessage : "正在等待新的定位，使用最近有效位置"
        } else if e.domain == kCLErrorDomain && e.code == CLError.denied.rawValue {
            stopStream()
            location = nil
            message = "定位被系统拒绝，请检查系统定位服务和 App 权限"
        } else {
            message = "定位暂时中断，将自动重试（\(e.code)）"
        }
    }
}

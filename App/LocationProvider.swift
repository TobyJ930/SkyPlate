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
    @Published private(set) var message = L("等待定位授权", "Waiting for location permission")
    @Published private(set) var permission = L("尚未检查", "Not checked")
    @Published private(set) var accuracy = "N/A"
    @Published private(set) var lastError = L("无", "None")
    private let manager: LocationManaging
    private let now: () -> Date
    private var enabled = false
    private var updating = false
    private var askedPermission = false
    private var lastStart = Date.distantPast

    #if targetEnvironment(simulator)
    var environment: String { L("iOS 模拟器", "iOS Simulator") }
    #else
    var environment: String { L("iPhone 真机", "iPhone device") }
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
        accuracy = manager.accuracyAuthorization == .reducedAccuracy ? L("大致位置", "Approximate location") : L("精确位置", "Precise location")
        switch manager.authorizationStatus {
        case .notDetermined:
            permission = L("尚未授权", "Not authorized")
            message = L("请允许使用位置", "Please allow location access")
            if enabled && !askedPermission {
                askedPermission = true
                manager.requestWhenInUseAuthorization()
            }
        case .authorizedAlways, .authorizedWhenInUse:
            permission = manager.authorizationStatus == .authorizedAlways ? L("始终允许", "Always allowed") : L("使用期间允许", "While using the app")
            guard enabled else { return }
            if let cached = manager.location, Self.isUsable(cached, at: now()) { location = cached }
            message = currentLocation == nil ? waitingMessage : L("已定位", "Location available")
            if !updating { beginStream() }
        case .denied, .restricted:
            stopStream()
            location = nil
            permission = manager.authorizationStatus == .restricted ? L("系统限制", "Restricted by system") : L("定位被拒绝", "Location denied")
            message = L("请检查系统定位服务及 SkyPlate 的位置权限", "Check Location Services and SkyPlate location permission")
        @unknown default:
            stopStream()
            location = nil
            permission = L("未知权限", "Unknown permission")
            message = L("定位权限状态未知，请重新打开 App", "Unknown location permission. Please reopen the app.")
        }
    }

    private var waitingMessage: String {
        #if targetEnvironment(simulator)
        return L("等待模拟位置：在模拟器 Features → Location 中选择位置", "Waiting for a simulated location: choose Features → Location in Simulator")
        #else
        return L("权限已允许，正在获取位置…可在靠窗或室外稍等", "Permission granted. Finding your location… Try waiting near a window or outdoors.")
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
        lastError = L("无", "None")
        stopStream()
        applyAuthorization()
    }

    func refreshLanguage() {
        if lastError == "无" || lastError == "None" { lastError = L("无", "None") }
        applyAuthorization()
        if !enabled { message = L("定位已暂停", "Location paused") }
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
        lastError = L("无", "None")
        message = manager.accuracyAuthorization == .reducedAccuracy ? L("已定位（大致位置，最近飞机可能有偏差）", "Approximate location available; nearest aircraft may be inaccurate") : L("已定位", "Location available")
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
            message = currentLocation == nil ? waitingMessage : L("正在等待新的定位，使用最近有效位置", "Waiting for a new fix; using the last valid location")
        } else if e.domain == kCLErrorDomain && e.code == CLError.denied.rawValue {
            stopStream()
            location = nil
            message = L("定位被系统拒绝，请检查系统定位服务和 App 权限", "Location denied by the system. Check Location Services and app permission.")
        } else {
            message = L("定位暂时中断，将自动重试（\(e.code)）", "Location temporarily interrupted; retrying (\(e.code))")
        }
    }
}

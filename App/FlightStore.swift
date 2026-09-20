import SwiftUI
import Combine
import ActivityKit

@MainActor
final class FlightStore: ObservableObject {
    @Published var flight: FlightSnapshot?
    @Published var status = "正在准备"
    @Published var busy = false
    @Published var activityMessage: String?
    @Published var activityEnabled = false
    @Published var demo = false
    @Published var radius = 100
    @Published var interval = 15
    @Published var metric = false
    let location = LocationProvider()
    private let service = FlightService()
    private var polling: Task<Void, Never>?
    private var routeTask: Task<Void, Never>?
    private var activity: Activity<FlightAttributes>?
    private var nextFetch = Date.distantPast
    private var active = false
    private var generation = 0

    init() {
        activity = Activity<FlightAttributes>.activities.first
        activityEnabled = activity != nil
    }

    func start() {
        guard !active else { return }
        active = true
        nextFetch = .distantPast
        if !demo { location.start() }
        polling = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stop() {
        active = false
        generation += 1
        polling?.cancel(); polling = nil
        routeTask?.cancel(); routeTask = nil
        location.stop()
    }

    func settingsChanged() {
        generation += 1
        routeTask?.cancel()
        if demo {
            location.stop()
            flight = .preview
            status = "演示数据 · 非真实航班"
        } else {
            flight = nil
            status = "正在查找附近航班…"
            if active { location.start() }
        }
        nextFetch = .distantPast
        Task { await endActivity(); if active { await refresh() } }
    }

    func refresh() async {
        guard active, !busy else { return }
        if demo {
            if flight?.demo != true { flight = .preview }
            status = "演示数据 · 非真实航班"
            return
        }
        location.renewIfNeeded()
        guard let point = location.currentLocation else {
            status = location.message
            await markUnavailable()
            return
        }
        guard Date() >= nextFetch else { return }
        busy = true
        defer { busy = false }
        nextFetch = Date().addingTimeInterval(Double(interval))
        let requestGeneration = generation
        do {
            let response = try await service.nearby(latitude: point.coordinate.latitude,
                longitude: point.coordinate.longitude, radius: radius)
            guard active, !Task.isCancelled, requestGeneration == generation else { return }
            guard let nearest = NearestFlight.select(response, latitude: point.coordinate.latitude,
                longitude: point.coordinate.longitude, radiusNM: Double(radius)) else {
                routeTask?.cancel()
                flight = nil
                status = "范围内暂无新鲜的空中飞机数据，可扩大搜索范围"
                await endActivity()
                return
            }
            let a = nearest.aircraft
            let callsign = FlightText.value(a.flight)
            let previous = flight
            let same = previous?.hex == a.hex && previous?.callsign == callsign
            let alt = a.alt_baro?.feet ?? a.alt_geom
            flight = FlightSnapshot(hex: a.hex, number: same ? previous!.number : "N/A",
                callsign: callsign, origin: same ? previous!.origin : "N/A",
                destination: same ? previous!.destination : "N/A",
                originName: same ? previous!.originName : "N/A", destinationName: same ? previous!.destinationName : "N/A",
                altitude: FlightText.number(alt.map { metric ? $0 * 0.3048 : $0 }, unit: metric ? "m" : "ft"),
                speed: FlightText.number(a.gs.flatMap { $0 >= 0 ? (metric ? $0 * 1.852 : $0) : nil }, unit: metric ? "km/h" : "kt"),
                elapsed: "N/A", arrival: "N/A", distance: String(format: "%.1f km", nearest.distanceKM),
                registration: FlightText.value(a.r), aircraftType: FlightText.value(a.t),
                observedAt: nearest.observedAt, expiresAt: nearest.observedAt.addingTimeInterval(60))
            status = "自动追踪最近飞机 · 每 \(interval) 秒刷新"
            await syncActivity()
            routeTask?.cancel()
            routeTask = Task {
                let route = await service.route(callsign: callsign)
                guard !Task.isCancelled, active, generation == requestGeneration,
                      flight?.hex == a.hex, flight?.callsign == callsign else { return }
                flight?.number = FlightText.value(route?.callsign_iata)
                flight?.origin = route?.origin?.label ?? "N/A"
                flight?.destination = route?.destination?.label ?? "N/A"
                flight?.originName = route?.origin?.detail ?? "N/A"
                flight?.destinationName = route?.destination?.detail ?? "N/A"
                await syncActivity()
            }
        } catch {
            guard active, !Task.isCancelled, requestGeneration == generation else { return }
            status = "\(error.localizedDescription) · 将自动重试"
            nextFetch = Date().addingTimeInterval(error is FlightServiceError ? 60 : 30)
            await markUnavailable()
        }
    }

    private func markUnavailable() async {
        guard flight?.unavailable == false else { return }
        flight?.unavailable = true
        await syncActivity()
    }

    func toggleActivity() async {
        if activity != nil { await endActivity(); return }
        guard let flight, !flight.unavailable, flight.expiresAt > Date() else {
            activityMessage = "请先等待有效航班数据"; return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            activityMessage = "请在 iPhone 设置中为 SkyPlate 开启实时活动"; return
        }
        do {
            activity = try Activity.request(attributes: FlightAttributes(title: "最近航班"),
                content: ActivityContent(state: flight, staleDate: flight.expiresAt), pushType: nil)
            activityEnabled = true
            activityMessage = "已开启。锁屏后显示最近一次数据，过期会提示返回 App 刷新。"
        } catch { activityMessage = error.localizedDescription }
    }

    private func syncActivity() async {
        guard let activity, let flight else { return }
        if activity.activityState == .dismissed || activity.activityState == .ended {
            self.activity = nil; activityEnabled = false; return
        }
        await activity.update(ActivityContent(state: flight,
            staleDate: flight.unavailable ? Date() : flight.expiresAt))
    }

    func endActivity() async {
        guard let old = activity else { return }
        activity = nil
        activityEnabled = false
        await old.end(nil, dismissalPolicy: .immediate)
    }
}

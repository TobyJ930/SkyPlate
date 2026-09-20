import Foundation

enum FlightServiceError: LocalizedError {
    case http(Int), invalidResponse, limited
    var errorDescription: String? {
        switch self {
        case .http(let code): return L("数据服务暂时不可用（HTTP \(code)）", "Data service unavailable (HTTP \(code))")
        case .invalidResponse: return L("航班数据格式有变化，请稍后重试", "Unexpected flight data format. Please try again later.")
        case .limited: return L("数据源限流，已暂缓请求，请稍后重试", "Rate limited. Requests paused; please try again later.")
        }
    }
}

actor FlightService {
    struct CachedRoute { let value: FlightRoute?; let until: Date }
    private var routes: [String: CachedRoute] = [:]
    private var resumeAfter = Date.distantPast
    private let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 15
        c.timeoutIntervalForResource = 20
        c.urlCache = nil
        return URLSession(configuration: c)
    }()

    private func data(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("SkyPlate/1.0 (personal iOS flight viewer)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FlightServiceError.invalidResponse }
        if http.statusCode == 429 {
            let seconds = Double(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 120
            resumeAfter = Date().addingTimeInterval(max(60, seconds))
            throw FlightServiceError.limited
        }
        guard (200..<300).contains(http.statusCode) else { throw FlightServiceError.http(http.statusCode) }
        return data
    }

    func nearby(latitude: Double, longitude: Double, radius: Int) async throws -> AircraftResponse {
        guard Date() >= resumeAfter else { throw FlightServiceError.limited }
        // Radius is nautical miles. Coordinates are only sent to ADSB.lol.
        let url = URL(string: "https://api.adsb.lol/v2/point/\(latitude)/\(longitude)/\(radius)")!
        let result = try await data(url)
        do { return try JSONDecoder().decode(AircraftResponse.self, from: result) }
        catch { throw FlightServiceError.invalidResponse }
    }

    func route(callsign: String) async -> FlightRoute? {
        guard callsign != "N/A", !callsign.isEmpty,
              callsign.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) else { return nil }
        if let cached = routes[callsign], cached.until > Date() { return cached.value }
        guard Date() >= resumeAfter else { return nil }
        let url = URL(string: "https://api.adsbdb.com/v0/callsign/\(callsign)")!
        let value: FlightRoute?
        do { value = try JSONDecoder().decode(RouteResponse.self, from: try await data(url)).response.flightroute }
        catch { value = nil }
        routes = routes.filter { $0.value.until > Date() }
        routes[callsign] = CachedRoute(value: value, until: Date().addingTimeInterval(value == nil ? 300 : 1800))
        return value
    }
}

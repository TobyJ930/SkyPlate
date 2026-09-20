import Foundation

enum FlightText {
    static func value(_ text: String?) -> String {
        let clean = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return clean.isEmpty ? "N/A" : clean
    }
    static func number(_ value: Double?, unit: String) -> String {
        guard let value, value.isFinite else { return "N/A" }
        return String(format: "%.0f %@", value, unit)
    }
}

struct FlightSnapshot: Codable, Hashable {
    var hex: String
    var number: String
    var callsign: String
    var origin: String
    var destination: String
    var originName: String
    var destinationName: String
    var altitude: String
    var speed: String
    var elapsed: String
    var arrival: String
    var distance: String
    var registration: String
    var aircraftType: String
    var observedAt: Date
    var expiresAt: Date
    var demo = false
    var unavailable = false

    static var preview: FlightSnapshot {
        FlightSnapshot(hex: "DEMO", number: "NZ123", callsign: "ANZ123",
            origin: "AKL", destination: "SYD", originName: "Auckland", destinationName: "Sydney",
            altitude: "12,000 ft", speed: "280 kt", elapsed: "N/A", arrival: "N/A",
            distance: "8.4 km", registration: "示例", aircraftType: "A320",
            observedAt: Date(), expiresAt: Date().addingTimeInterval(90), demo: true)
    }
}

enum Altitude: Decodable, Equatable {
    case feet(Double), ground, unknown
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let n = try? c.decode(Double.self), n.isFinite { self = .feet(n) }
        else if let s = try? c.decode(String.self), s.lowercased() == "ground" { self = .ground }
        else { self = .unknown }
    }
    var feet: Double? { if case .feet(let n) = self { return n }; return nil }
}

struct Aircraft: Decodable {
    let hex: String
    var flight: String?
    var r: String?
    var t: String?
    var alt_baro: Altitude?
    var alt_geom: Double?
    var gs: Double?
    var lat: Double?
    var lon: Double?
    var seen_pos: Double?
}

struct AircraftResponse: Decodable {
    let ac: [Aircraft]
    let now: Double?
    // The provider's v2 timestamp is milliseconds since the Unix epoch.
    var timestamp: Date? {
        guard let now, now.isFinite, now > 0 else { return nil }
        return Date(timeIntervalSince1970: now > 100_000_000_000 ? now / 1000 : now)
    }
}

struct Airport: Decodable {
    var iata_code: String?
    var icao_code: String?
    var municipality: String?
    var name: String?
    var label: String {
        let iata = FlightText.value(iata_code)
        return iata == "N/A" ? FlightText.value(icao_code) : iata
    }
    var detail: String { FlightText.value(municipality ?? name) }
}

struct FlightRoute: Decodable {
    var callsign_iata: String?
    var origin: Airport?
    var destination: Airport?
}

struct RouteResponse: Decodable {
    struct Payload: Decodable { var flightroute: FlightRoute? }
    var response: Payload
}

struct LocatedAircraft {
    let aircraft: Aircraft
    let distanceKM: Double
    let observedAt: Date
}

enum NearestFlight {
    static func distance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let p = Double.pi / 180
        let a = pow(sin((lat2 - lat1) * p / 2), 2)
            + cos(lat1 * p) * cos(lat2 * p) * pow(sin((lon2 - lon1) * p / 2), 2)
        return 6371 * 2 * atan2(sqrt(min(1, max(0, a))), sqrt(max(0, 1 - a)))
    }

    static func select(_ response: AircraftResponse, latitude: Double, longitude: Double,
                       radiusNM: Double, now: Date = Date()) -> LocatedAircraft? {
        guard let feedTime = response.timestamp, abs(feedTime.timeIntervalSince(now)) < 90 else { return nil }
        return response.ac.compactMap { aircraft -> LocatedAircraft? in
            guard aircraft.alt_baro != .ground,
                  // Require affirmative airborne altitude; unknown ground state is excluded.
                  let altitude = aircraft.alt_baro?.feet ?? aircraft.alt_geom, altitude > 0,
                  let lat = aircraft.lat, let lon = aircraft.lon,
                  (-90...90).contains(lat), (-180...180).contains(lon),
                  let age = aircraft.seen_pos, age.isFinite, age >= 0 else { return nil }
            let observed = feedTime.addingTimeInterval(-age)
            guard now.timeIntervalSince(observed) >= -5, now.timeIntervalSince(observed) <= 60 else { return nil }
            let km = distance(lat1: latitude, lon1: longitude, lat2: lat, lon2: lon)
            guard km <= radiusNM * 1.852 else { return nil }
            return LocatedAircraft(aircraft: aircraft, distanceKM: km, observedAt: observed)
        }.min { $0.distanceKM < $1.distanceKM }
    }
}

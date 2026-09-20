import Foundation

struct AircraftPhoto: Equatable {
    let thumbnail: URL
    let original: URL
    let aircraftHex: String
}

struct AircraftPhotoResponse: Decodable {
    struct Payload: Decodable { var aircraft: Entry? }
    struct Entry: Decodable {
        var mode_s: String?
        var url_photo: String?
        var url_photo_thumbnail: String?
    }
    var response: Payload
    func photo(for hex: String) -> AircraftPhoto? {
        guard let aircraft = response.aircraft,
              aircraft.mode_s?.lowercased() == hex.lowercased(),
              let original = Self.safeURL(aircraft.url_photo),
              let thumbnail = Self.safeURL(aircraft.url_photo_thumbnail) else { return nil }
        return AircraftPhoto(thumbnail: thumbnail, original: original, aircraftHex: hex.lowercased())
    }
    static func safeURL(_ string: String?) -> URL? {
        guard let string, let url = URL(string: string), url.scheme == "https",
              let host = url.host?.lowercased(),
              host == "airport-data.com" || host.hasSuffix(".airport-data.com") else { return nil }
        return url
    }
}

actor PhotoService {
    struct Entry { let value: AircraftPhoto?; let until: Date }
    private var cache: [String: Entry] = [:]
    private var resumeAfter = Date.distantPast
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 12
        return URLSession(configuration: configuration)
    }()
    func photo(hex: String) async -> AircraftPhoto? {
        let key = hex.lowercased()
        guard key.count == 6, key.allSatisfy({ "0123456789abcdef".contains($0) }) else { return nil }
        if let item = cache[key], item.until > Date() { return item.value }
        guard Date() >= resumeAfter else { return nil }
        let value: AircraftPhoto?
        do {
            let url = URL(string: "https://api.adsbdb.com/v0/aircraft/\(key)")!
            let (bytes, response) = try await session.data(from: url)
            guard let response = response as? HTTPURLResponse else { return nil }
            if response.statusCode == 429 {
                let retry = Double(response.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 120
                resumeAfter = Date().addingTimeInterval(max(60, retry))
            }
            if response.statusCode == 200 {
                value = try JSONDecoder().decode(AircraftPhotoResponse.self, from: bytes).photo(for: key)
            } else { value = nil }
        } catch {
            if Task.isCancelled { return nil }
            value = nil
        }
        guard !Task.isCancelled else { return nil }
        cache = cache.filter { $0.value.until > Date() }
        if cache.count >= 100 { cache.removeAll() }
        cache[key] = Entry(value: value, until: Date().addingTimeInterval(value == nil ? 300 : 21600))
        return value
    }
}

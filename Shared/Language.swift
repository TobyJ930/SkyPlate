import Foundation

enum AppLanguage {
    static let preferenceKey = "SkyPlate.language"
    static var current: String {
        UserDefaults.standard.string(forKey: preferenceKey) == "en" ? "en" : "zh-Hans"
    }
}

/// Explicit language in Live Activity payloads avoids relying on separate
/// widget/app preference containers. Airline/airport proper names stay as supplied.
func L(_ chinese: String, _ english: String, language: String? = nil) -> String {
    (language ?? AppLanguage.current) == "en" ? english : chinese
}

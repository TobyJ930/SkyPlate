import XCTest
@testable import SkyPlate

final class EnrichmentTests: XCTestCase {
    func testSquawkPreservesLeadingZeroAndAcceptsNumericSource() throws {
        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(Squawk.self, from: Data("\"0042\"".utf8)).code, "0042")
        XCTAssertEqual(try decoder.decode(Squawk.self, from: Data("42".utf8)).code, "0042")
        XCTAssertEqual(try decoder.decode(Squawk.self, from: Data("\"0000\"".utf8)).code, "0000")
        XCTAssertEqual(try decoder.decode(Squawk.self, from: Data("\"7800\"".utf8)).code, "N/A")
        XCTAssertEqual(try decoder.decode(Squawk.self, from: Data("null".utf8)).code, "N/A")
    }

    func testLanguageAndAirlineNamesUseExplicitSelection() {
        let airline = Airline(name: "Air New Zealand", icao: "ANZ", iata: "NZ")
        XCTAssertEqual(airline.displayName(language: "zh-Hans"), "新西兰航空")
        XCTAssertEqual(airline.displayName(language: "en"), "Air New Zealand")
        XCTAssertEqual(L("航空公司", "Airline", language: "en"), "Airline")
        XCTAssertEqual(L("航空公司", "Airline", language: "zh-Hans"), "航空公司")
        XCTAssertEqual(Airline(name: nil, icao: nil, iata: nil).displayName(language: "en"), "N/A")
    }

    func testPhotoMustMatchAircraftAndUseApprovedHTTPSHost() throws {
        let json = """
        {"response":{"aircraft":{"mode_s":"C82953","url_photo":"https://image.airport-data.com/aircraft/test.jpg","url_photo_thumbnail":"https://airport-data.com/images/test.jpg"}}}
        """
        let payload = try JSONDecoder().decode(AircraftPhotoResponse.self, from: Data(json.utf8))
        XCTAssertNotNil(payload.photo(for: "c82953"))
        XCTAssertNil(payload.photo(for: "c12345"))
        XCTAssertNil(AircraftPhotoResponse.safeURL("http://airport-data.com/test.jpg"))
        XCTAssertNil(AircraftPhotoResponse.safeURL("https://airport-data.com.other.invalid/test.jpg"))
        XCTAssertNil(AircraftPhotoResponse.safeURL(nil))
    }

    func testOldLiveActivityPayloadRemainsDecodable() throws {
        let data = try JSONEncoder().encode(FlightSnapshot.preview)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["airline", "squawk", "language"] { json.removeValue(forKey: key) }
        let legacy = try JSONDecoder().decode(FlightSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(legacy.airline)
        XCTAssertNil(legacy.squawk)
        XCTAssertNil(legacy.language)
    }
}

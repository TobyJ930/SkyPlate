import XCTest
@testable import SkyPlate

final class FlightTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func feed(_ rows: String, age: Double = 0) throws -> AircraftResponse {
        let json = "{\"now\":\((now.timeIntervalSince1970 - age) * 1000),\"ac\":[\(rows)]}"
        return try JSONDecoder().decode(AircraftResponse.self, from: Data(json.utf8))
    }
    private func nearest(_ feed: AircraftResponse) -> LocatedAircraft? {
        NearestFlight.select(feed, latitude: 0, longitude: 0, radiusNM: 100, now: now)
    }

    func testRejectsGroundAndOldPositionsEvenWhenCloser() throws {
        let f = try feed("""
        {"hex":"ground","lat":0,"lon":0.001,"alt_baro":"ground","alt_geom":80,"seen_pos":0},
        {"hex":"old","lat":0,"lon":0.002,"alt_baro":3000,"seen_pos":61},
        {"hex":"fresh","lat":0,"lon":0.1,"alt_baro":8000,"seen_pos":2},
        {"hex":"far","lat":0,"lon":0.2,"alt_baro":9000,"seen_pos":1}
        """)
        XCTAssertEqual(nearest(f)?.aircraft.hex, "fresh")
    }

    func testCachedServerResponseIsNotTreatedAsLive() throws {
        let f = try feed("{\"hex\":\"a\",\"lat\":0,\"lon\":0,\"alt_baro\":1000,\"seen_pos\":1}", age: 120)
        XCTAssertNil(nearest(f))
    }

    func testFeedAgeAndPositionAgeAreCombined() throws {
        let f = try feed("{\"hex\":\"a\",\"lat\":0,\"lon\":0,\"alt_baro\":1000,\"seen_pos\":30}", age: 40)
        XCTAssertNil(nearest(f))
    }

    func testUnknownGroundStateAndMissingCoordinatesAreExcluded() throws {
        let f = try feed("""
        {"hex":"unknown","lat":0,"lon":0,"seen_pos":0},
        {"hex":"missing","alt_baro":1000,"seen_pos":0}
        """)
        XCTAssertNil(nearest(f))
    }

    func testRadiusAndDatelineDistance() throws {
        XCTAssertEqual(NearestFlight.distance(lat1: 0, lon1: 179.9, lat2: 0, lon2: -179.9), 22.239, accuracy: 0.01)
        let f = try feed("{\"hex\":\"far\",\"lat\":0,\"lon\":5,\"alt_baro\":1000,\"seen_pos\":0}")
        XCTAssertNil(nearest(f))
    }

    func testMissingFieldsRemainNAAndZeroIsNotMissing() {
        XCTAssertEqual(FlightText.value("  "), "N/A")
        XCTAssertEqual(FlightText.number(nil, unit: "kt"), "N/A")
        XCTAssertEqual(FlightText.number(0, unit: "kt"), "0 kt")
        XCTAssertEqual(FlightSnapshot.preview.elapsed, "N/A")
        XCTAssertEqual(FlightSnapshot.preview.arrival, "N/A")
    }

    func testRouteUsesReturnedCommercialNumber() throws {
        let json = """
        {"response":{"flightroute":{"callsign_iata":"NZ188","origin":{"iata_code":"OOL"},"destination":{"icao_code":"NZAA"}}}}
        """
        let route = try JSONDecoder().decode(RouteResponse.self, from: Data(json.utf8)).response.flightroute
        XCTAssertEqual(route?.callsign_iata, "NZ188")
        XCTAssertEqual(route?.origin?.label, "OOL")
        XCTAssertEqual(route?.destination?.label, "NZAA")
    }
}

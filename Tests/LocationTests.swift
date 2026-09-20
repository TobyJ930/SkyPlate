import XCTest
import CoreLocation
@testable import SkyPlate

@MainActor
private final class FakeLocationManager: LocationManaging {
    weak var delegate: CLLocationManagerDelegate?
    var desiredAccuracy: CLLocationAccuracy = 0
    var distanceFilter: CLLocationDistance = 0
    var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    var accuracyAuthorization: CLAccuracyAuthorization = .fullAccuracy
    var location: CLLocation?
    var starts = 0
    var stops = 0
    var permissionRequests = 0
    func requestWhenInUseAuthorization() { permissionRequests += 1 }
    func startUpdatingLocation() { starts += 1 }
    func stopUpdatingLocation() { stops += 1 }
}

final class LocationTests: XCTestCase {
    @MainActor
    func testRepeatedStartDoesNotDuplicateStreamOrPermissionRequest() {
        let manager = FakeLocationManager()
        manager.authorizationStatus = .notDetermined
        let provider = LocationProvider(manager: manager)
        provider.start(); provider.start()
        XCTAssertEqual(manager.permissionRequests, 1)
        XCTAssertEqual(manager.starts, 0)
        manager.authorizationStatus = .authorizedWhenInUse
        provider.start(); provider.start()
        XCTAssertEqual(manager.starts, 1)
    }

    @MainActor
    func testTemporaryErrorKeepsListeningAndPreservesValidPosition() {
        let manager = FakeLocationManager()
        let provider = LocationProvider(manager: manager)
        provider.start()
        provider.receive([CLLocation(latitude: -36.8485, longitude: 174.7633)])
        provider.receive(NSError(domain: kCLErrorDomain, code: CLError.locationUnknown.rawValue))
        XCTAssertNotNil(provider.currentLocation)
        XCTAssertEqual(manager.stops, 0)
        XCTAssertEqual(provider.permission, "使用期间允许")
        XCTAssertFalse(provider.message.contains("权限"))
    }

    @MainActor
    func testNoFixRetriesAreThrottledAndBackgroundDoesNotRetry() {
        var clock = Date(timeIntervalSince1970: 1_800_000_000)
        let manager = FakeLocationManager()
        let provider = LocationProvider(manager: manager, now: { clock })
        provider.start()
        clock = clock.addingTimeInterval(10)
        provider.renewIfNeeded()
        XCTAssertEqual(manager.starts, 1)
        clock = clock.addingTimeInterval(21)
        provider.renewIfNeeded()
        XCTAssertEqual(manager.starts, 2)
        provider.stop()
        clock = clock.addingTimeInterval(60)
        provider.renewIfNeeded()
        XCTAssertEqual(manager.starts, 2)
    }

    @MainActor
    func testDeniedAuthorizationDiscardsCachedLocation() {
        let manager = FakeLocationManager()
        manager.location = CLLocation(latitude: -36.8, longitude: 174.7)
        let provider = LocationProvider(manager: manager)
        provider.start()
        XCTAssertNotNil(provider.currentLocation)
        manager.authorizationStatus = .denied
        provider.start()
        XCTAssertNil(provider.currentLocation)
        XCTAssertEqual(manager.stops, 1)
    }

    @MainActor
    func testInvalidAndOldLocationsCannotBeUsed() {
        let now = Date()
        func fix(age: TimeInterval, accuracy: Double) -> CLLocation {
            CLLocation(coordinate: .init(latitude: 0, longitude: 0), altitude: 0,
                       horizontalAccuracy: accuracy, verticalAccuracy: 0, timestamp: now.addingTimeInterval(-age))
        }
        XCTAssertFalse(LocationProvider.isUsable(fix(age: 121, accuracy: 10), at: now))
        XCTAssertFalse(LocationProvider.isUsable(fix(age: 0, accuracy: -1), at: now))
        XCTAssertFalse(LocationProvider.isUsable(fix(age: -30, accuracy: 10), at: now))
        XCTAssertTrue(LocationProvider.isUsable(fix(age: 0, accuracy: 10), at: now))
    }
}

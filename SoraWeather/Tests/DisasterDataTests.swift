import XCTest
@testable import SoraWeatherCore
final class DisasterDataTests: XCTestCase {
    private let time = Date(timeIntervalSince1970: 1_800_000_000)
    private func item(_ id: String = "one", _ text: String = "大雨警報") -> DisasterItem { DisasterItem(id: id, title: text, detail: "M 5.7 · 最大震度 5+ · 2026-11-08T01:04:00+09:00", issued: time) }
    func testPartialFailureRetainsOnlyFailedComponentAndItsTimestamp() {
        var record = SafetyRecord()
        record.merge(warnings: [item()], quakes: [item("quake")], issued: time, warningTime: time, quakeTime: time)
        let next = time.addingTimeInterval(60)
        record.merge(warnings: [], quakes: [], issued: nil, warningTime: nil, quakeTime: next)
        XCTAssertEqual(record.warnings.count, 1); XCTAssertEqual(record.warningsFetched, time)
        XCTAssertTrue(record.warningsOffline); XCTAssertFalse(record.quakesOffline); XCTAssertTrue(record.quakes.isEmpty)
        record.merge(warnings: [], quakes: [], issued: next, warningTime: next, quakeTime: nil)
        XCTAssertTrue(record.warnings.isEmpty); XCTAssertEqual(record.warningsFetched, next); XCTAssertFalse(record.warningsOffline)
    }
    func testCacheRoundTripPreservesDatesAndRestoresOfflineProvenance() throws {
        var record = SafetyRecord(); record.merge(warnings: [item()], quakes: [], issued: time, warningTime: time, quakeTime: time)
        let saved = try JSONDecoder().decode(SafetyRecord.self, from: JSONEncoder().encode(record)).restored()
        XCTAssertTrue(saved.offline); XCTAssertEqual(saved.updated, time); XCTAssertEqual(saved.warnings.first?.id, "one")
    }
    func testOlderResponseCannotResurrectCancelledWarning() {
        var record = SafetyRecord(); record.merge(warnings: [], quakes: [], issued: time, warningTime: time, quakeTime: time)
        record.merge(warnings: [item()], quakes: [], issued: time.addingTimeInterval(-60), warningTime: time.addingTimeInterval(-60), quakeTime: nil)
        XCTAssertTrue(record.warnings.isEmpty); XCTAssertEqual(record.warningsFetched, time)
    }
    func testQuakesDeduplicateCapAndProjectFields() {
        var record = SafetyRecord()
        let values = (0..<15).map { item(String($0), "静岡県西部") }
        record.merge(warnings: [], quakes: values + values, issued: time, warningTime: time, quakeTime: time)
        XCTAssertEqual(record.quakes.count, 10)
        let value = EarthquakePresentation(values[0])
        XCTAssertEqual(value.magnitude, "5.7"); XCTAssertEqual(value.intensityLabel, "5強"); XCTAssertEqual(value.intensityRank, 6)
        XCTAssertEqual(value.occurred, JapanTime.iso("2026-11-08T01:04:00+09:00"))
        let unknown = EarthquakePresentation(DisasterItem(id: "bad", title: "JMA", detail: "", issued: time))
        XCTAssertEqual(unknown.intensityRank, 0); XCTAssertEqual(unknown.magnitude, "—"); XCTAssertNil(unknown.occurred)
    }
    func testNotificationCityRoutesSupportNewPayloadAndExistingIdentifiers() {
        XCTAssertEqual(SafetyDestination.cityKey(userInfo: ["regionID": "tokyo"], identifier: "rain.osaka.x"), "tokyo")
        XCTAssertEqual(SafetyDestination.cityKey(userInfo: [:], identifier: "rain.osaka.x"), "osaka")
        XCTAssertEqual(SafetyDestination.cityKey(userInfo: ["cityID": "saved-id"], identifier: "warning"), "saved-id")
        XCTAssertNil(SafetyDestination.cityKey(userInfo: ["regionID": 123], identifier: "malformed"))
        XCTAssertNil(SafetyDestination.cityKey(userInfo: [:], identifier: "other.osaka.x"))
        XCTAssertEqual(SafetyDestination.cityKey(userInfo: [:], identifier: "rain.place-270000-34.500-135.500.token"), "place-270000-34.500-135.500")
    }
}

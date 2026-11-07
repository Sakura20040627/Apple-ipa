import XCTest
@testable import SoraWeatherCore

final class RainPolicyTests: XCTestCase {
    let now = JapanTime.iso("2026-11-08T02:00:00+09:00")!
    func points(_ intensity: Double = 0.8, lead: Double = 1200) -> [RainPoint] { [RainPoint(date: now, intensity: 0, forecast: false), RainPoint(date: now.addingTimeInterval(lead), intensity: intensity, forecast: true)] }
    func plan(_ p: [RainPoint]? = nil, enabled: Bool = true, allowed: Bool = true, age: Double = 0, last: Date? = nil) -> RainPlan? { RainPolicy.plan(points: p ?? points(), fetched: now.addingTimeInterval(-age), now: now, region: "osaka", enabled: enabled, authorized: allowed, lastDelivered: last) }
    func testRainSchemaAndUnits() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "yahoo-rain", withExtension: "json", subdirectory: "Fixtures"))
        let values = try YahooParser.rain(Data(contentsOf: url)); XCTAssertEqual(values.count, 3); XCTAssertFalse(values[0].forecast); XCTAssertEqual(values[2].intensity,0.8)
    }
    func testSchedulesTenMinutesBeforeForecast() { XCTAssertEqual(plan()?.fireDate,now.addingTimeInterval(600)) }
    func testNearOnsetClampsToFiveSeconds() { XCTAssertEqual(plan(points(lead: 300))?.fireDate,now.addingTimeInterval(5)) }
    func testPermissionDeniedProducesNoPlan() { XCTAssertNil(plan(allowed: false)) }
    func testOptOutProducesNoPlan() { XCTAssertNil(plan(enabled: false)) }
    func testStaleFetchProducesNoPlan() { XCTAssertNil(plan(age: 901)) }
    func testFutureFetchRejected() { XCTAssertNil(plan(age: -61)) }
    func testBelowThresholdProducesNoPlan() { XCTAssertNil(plan(points(0.49))) }
    func testDryRefreshProducesNoPlan() { XCTAssertNil(plan(points(0))) }
    func testNoSourceProducesNoPlan() { XCTAssertNil(plan([])) }
    func testAlreadyRainingProducesNoOnset() {
        XCTAssertNil(plan([RainPoint(date: now, intensity: 1, forecast: false), RainPoint(date: now.addingTimeInterval(1200), intensity: 1, forecast: true)]))
    }
    func testPastForecastIgnored() { XCTAssertNil(plan(points(lead: -60))) }
    func testBeyondOneHourIgnored() { XCTAssertNil(plan(points(lead: 3601))) }
    func testCooldownSuppressesRepeatedNotifications() { XCTAssertNil(plan(last: now.addingTimeInterval(-3599))); XCTAssertNotNil(plan(last: now.addingTimeInterval(-3600))) }
    func testUnsortedPointsUseEarliestWetTime() {
        let p = [RainPoint(date: now.addingTimeInterval(3000), intensity: 1, forecast: true),RainPoint(date: now.addingTimeInterval(1200), intensity: 1, forecast: true)]
        XCTAssertEqual(plan(p)?.onset,now.addingTimeInterval(1200))
    }
    func snapshot(age: Double = 0, probability: Int? = 60, rain: Double? = nil) -> WeatherSnapshot {
        WeatherSnapshot(region: .osaka, source: "JMA", issued: now.addingTimeInterval(-age), fetched: now.addingTimeInterval(-age), days: [], slots: [ForecastSlot(date: now.addingTimeInterval(3600),temperature: nil,rainMM: rain,probability: probability,condition: "",durationHours: 6)])
    }
    func testForecastWindowProbabilityThreshold() { XCTAssertNotNil(ForecastRainPolicy.window(snapshot:snapshot(),now:now)); XCTAssertNil(ForecastRainPolicy.window(snapshot:snapshot(probability:49),now:now)) }
    func testForecastWindowMissingProbabilityNotZeroRain() { XCTAssertNil(ForecastRainPolicy.window(snapshot:snapshot(probability:nil),now:now)); XCTAssertNotNil(ForecastRainPolicy.window(snapshot:snapshot(probability:nil,rain:0.5),now:now)) }
    func testOldForecastWindowNotScheduled() { XCTAssertNil(ForecastRainPolicy.window(snapshot:snapshot(age:3601),now:now)) }
    func testPlanHasRegionScopedIdentifier() { XCTAssertEqual(plan()?.id,"rain.osaka") }
}

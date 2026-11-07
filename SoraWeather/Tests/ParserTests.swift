import XCTest
@testable import SoraWeatherCore

final class ParserTests: XCTestCase {
    func fixture(_ name: String, _ ext: String = "json") throws -> Data { try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures"))) }
    func html(_ name: String) throws -> String { String(decoding: try fixture(name, "html"), as: UTF8.self) }
    let now = JapanTime.iso("2026-11-08T02:00:00+09:00")!
    func testYahooLiveExtractEightDays() throws {
        let result = try YahooParser.forecast(html("yahoo-osaka"), region: .osaka, now: now)
        XCTAssertEqual(result.days.count, 8); XCTAssertEqual(result.days.first?.high, 18); XCTAssertEqual(result.days.first?.low, 10)
        XCTAssertEqual(result.days.last?.probability, 70); XCTAssertEqual(result.source, "Yahoo! JAPAN")
        XCTAssertEqual(result.slots.count, 8); XCTAssertEqual(result.slots[3].probability, 10)
        XCTAssertNil(result.days.first?.probability, "Six-hour probability is not a daily probability")
    }
    func testYahooIssueIsNotFetchTime() throws {
        let result = try YahooParser.forecast(html("yahoo-osaka"), region: .osaka, now: now)
        XCTAssertEqual(result.issued, JapanTime.iso("2026-11-07T22:00:00+09:00")); XCTAssertNotEqual(result.issued, result.fetched)
    }
    func testYahooRejectsLoginOrLayoutChange() { XCTAssertThrowsError(try YahooParser.forecast("<html>login</html>", region: .osaka, now: now)) }
    func testYahooRejectsMissingTemperatureStructure() throws {
        let changed = try html("yahoo-osaka").replacingOccurrences(of: "class=\"high\"", with: "class=\"changed\"")
        XCTAssertThrowsError(try YahooParser.forecast(changed, region: .osaka, now: now))
    }
    func testPinpointActualThreeHourSlots() throws {
        let (issued, slots) = try YahooParser.pinpoint(html("yahoo-pinpoint"))
        XCTAssertEqual(issued, JapanTime.iso("2026-11-08T00:00:00+09:00")); XCTAssertEqual(slots.count, 16)
        XCTAssertEqual(slots[1].date.timeIntervalSince(slots[0].date), 3*3600)
        XCTAssertEqual(slots.first?.temperature, 11); XCTAssertEqual(slots[6].rainMM, 0.1)
        XCTAssertTrue(slots.allSatisfy { $0.durationHours == 3 && $0.probability == nil })
    }
    func testPinpointRejectsShiftedRowLabels() throws {
        let changed = try html("yahoo-pinpoint").replacingOccurrences(of: "気温", with: "Unknown")
        XCTAssertThrowsError(try YahooParser.pinpoint(changed))
    }
    func testJMARealDataDateAndAreaAlignment() throws {
        let w = try JMAParser.forecast(fixture("jma-osaka"), region: .osaka, now: now)
        let day = try XCTUnwrap(w.days.first { $0.id == "2026-11-09" })
        XCTAssertEqual(day.high, 19); XCTAssertEqual(day.low, 12); XCTAssertEqual(day.probability, 60)
        XCTAssertTrue(day.condition.contains("雨")); XCTAssertEqual(w.slots[0].probability, 10)
    }
    func testJMAEmptyStringsRemainMissing() throws {
        let w = try JMAParser.forecast(fixture("jma-osaka"), region: .osaka, now: now)
        let day = try XCTUnwrap(w.days.first { $0.id == "2026-11-07" }); XCTAssertNil(day.high); XCTAssertNil(day.low); XCTAssertNil(day.probability)
    }
    func testJMATodayTemperatureForecastNotObservation() throws {
        let w = try JMAParser.forecast(fixture("jma-osaka"), region: .osaka, now: now)
        let day = try XCTUnwrap(w.days.first { $0.id == "2026-11-08" }); XCTAssertEqual(day.high, 18); XCTAssertEqual(day.low, 10)
    }
    func testJMARejectsWrongRegion() throws { XCTAssertThrowsError(try JMAParser.forecast(fixture("jma-osaka"), region: Region.supported[1], now: now)) }
    func testJMARejectsMalformedJSON() { XCTAssertThrowsError(try JMAParser.forecast(Data("{}".utf8), region: .osaka, now: now)) }
    func testCancelledWarningsNotActive() throws { let (_, warnings) = try JMAParser.warnings(fixture("jma-warning"), office: "270000"); XCTAssertTrue(warnings.isEmpty) }
    func testWarningSummaryScopeAndCancellation() throws {
        let bytes = Data(#"{"reportDatetime":"2026-11-08T00:00:00+09:00","headlineText":"大雨","areaTypes":[{"areas":[{"code":"270000","warnings":[{"code":"03","status":"発表"},{"code":"21","status":"解除"}]},{"code":"2710000","warnings":[{"code":"03","status":"継続"}]}]}]}"#.utf8)
        let (_, warnings) = try JMAParser.warnings(bytes, office: "270000"); XCTAssertEqual(warnings.count, 1); XCTAssertEqual(warnings[0].id, "270000-03")
    }
    func testQuakeFixtureDecodesActualSchema() throws { let q = try JMAParser.earthquakes(fixture("jma-quake")); XCTAssertFalse(q.isEmpty); XCTAssertEqual(Set(q.map(\.id)).count, q.count) }
    func testQuakeRevisionsDeduplicated() throws {
        let bytes = Data(#"[{"eid":"1","rdt":"2026-11-08T00:00:00+09:00","anm":"old"},{"eid":"1","rdt":"2026-11-08T01:00:00+09:00","anm":"new"}]"#.utf8)
        let q = try JMAParser.earthquakes(bytes); XCTAssertEqual(q.count, 1); XCTAssertEqual(q[0].title, "new")
    }
    func testLatestQuakeCancellationSuppressesOldRevision() throws {
        let bytes = Data(#"[{"eid":"1","rdt":"2026-11-08T00:00:00+09:00","anm":"old"},{"eid":"1","rdt":"2026-11-08T01:00:00+09:00","ift":"取消"}]"#.utf8)
        XCTAssertTrue(try JMAParser.earthquakes(bytes).isEmpty)
    }
    func testTenDaysMissingNotFabricated() throws {
        let w = try YahooParser.forecast(html("yahoo-osaka"), region: .osaka, now: now)
        let days = w.tenDays(from: now); XCTAssertEqual(days.count, 10); XCTAssertTrue(days[8].condition.isEmpty); XCTAssertNil(days[9].high); XCTAssertEqual(days[9].id, "2026-11-17")
    }
    func testJapanMidnightAndYearRollover() {
        let ref = JapanTime.iso("2026-12-31T23:50:00+09:00")!
        XCTAssertEqual(JapanTime.key(JapanTime.monthDay(1, 1, near: ref)!), "2027-01-01")
        XCTAssertEqual(JapanTime.key(now), "2026-11-08")
    }
    func testSnapshotStalenessUsesIssueTime() throws {
        let w = try YahooParser.forecast(html("yahoo-osaka"), region: .osaka, now: now)
        XCTAssertFalse(w.stale(at: now)); XCTAssertTrue(w.stale(at: now.addingTimeInterval(3*3600)))
    }
    func testSlotIDsDoNotCollideAcrossIntervals() {
        let a = ForecastSlot(date: now, temperature: 18, rainMM: 0, probability: nil, condition: "晴", durationHours: 3)
        let b = ForecastSlot(date: now, temperature: nil, rainMM: nil, probability: 10, condition: "", durationHours: 6)
        XCTAssertNotEqual(a.id,b.id)
    }
    func testNearestRegionOutsideCoverageNotOsaka() { XCTAssertNil(Region.nearest(latitude: 0, longitude: 0)); XCTAssertEqual(Region.nearest(latitude: 34.61, longitude: 135.51)?.id, "osaka") }
    func testRoundTripCachePreservesMissingValues() throws {
        let w = try JMAParser.forecast(fixture("jma-osaka"), region: .osaka, now: now)
        let cached = try JSONDecoder().decode(WeatherSnapshot.self, from: JSONEncoder().encode(w)); XCTAssertEqual(cached.days,w.days); XCTAssertEqual(cached.issued,w.issued)
    }
}

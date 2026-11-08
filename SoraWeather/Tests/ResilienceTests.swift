import XCTest
@testable import SoraWeatherCore
final class ResilienceTests: XCTestCase {
    let now = JapanTime.iso("2026-11-08T02:00:00+09:00")!
    func data(_ name: String, _ ext: String = "html") throws -> Data { try Data(contentsOf: XCTUnwrap(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures"))) }
    func testPartialForecastRetainsOtherFields() throws {
        let html = String(decoding: try data("yahoo-osaka"), as: UTF8.self).replacingOccurrences(of: "class=\"high\"", with: "class=\"missing\"")
        let result = try XCTUnwrap(YahooParser.resilientForecast(html, region: .osaka, now: now))
        XCTAssertNil(result.days.first?.high); XCTAssertEqual(result.days.first?.low, 10)
    }
    func testQuoteAndWhitespaceChanges() throws {
        let html = String(decoding: try data("yahoo-osaka"), as: UTF8.self).replacingOccurrences(of: "=\"", with: " = '").replacingOccurrences(of: "\"", with: "'")
        XCTAssertNotNil(YahooParser.resilientForecast(html, region: .osaka, now: now))
    }
    func testEmptyYahooResponseIsAbsent() { XCTAssertNil(YahooParser.resilientForecast("<html>unavailable</html>", region: .osaka, now: now)); XCTAssertNil(YahooParser.resilientPinpoint("")) }
    func testPinpointMissingWeatherRowKeepsTemperatures() throws {
        let html = String(decoding: try data("yahoo-pinpoint"), as: UTF8.self).replacingOccurrences(of: "天気</small>", with: "unknown</small>")
        let (_, slots) = try XCTUnwrap(YahooParser.resilientPinpoint(html)); XCTAssertEqual(slots.count, 16); XCTAssertEqual(slots.first?.temperature, 11)
    }
    func testMalformedRainEntrySkippedIndependently() throws {
        let bytes = Data(#"{"Feature":[{"Property":{"WeatherList":{"Weather":[{"Date":"202611080220","Type":"forecast","Rainfall":1},{"Type":"forecast"}]}}}]}"#.utf8)
        XCTAssertEqual(try YahooParser.rain(bytes).count, 1)
    }
    func testJMAOnlyFallbackPreservesAllData() throws {
        let jma = try JMAParser.forecast(data("jma-osaka", "json"), region: .osaka, now: now)
        let merged = WeatherMerge.combine(primary: jma, supplement: nil)
        XCTAssertEqual(merged.days, jma.days); XCTAssertEqual(merged.slots, jma.slots); XCTAssertEqual(merged.source, "JMA")
    }
    func testYahooCannotOverrideJMAForecast() throws {
        let jma = try JMAParser.forecast(data("jma-osaka", "json"), region: .osaka, now: now)
        let yahoo = try XCTUnwrap(YahooParser.resilientForecast(String(decoding: data("yahoo-osaka"), as: UTF8.self), region: .osaka, now: now))
        let merged = WeatherMerge.combine(primary: jma, supplement: yahoo)
        let day = try XCTUnwrap(merged.days.first { $0.id == "2026-11-09" })
        XCTAssertEqual(day.high, 19); XCTAssertEqual(day.probability, 60); XCTAssertEqual(merged.issued, jma.issued)
    }
    func testStaleSupplementNotMerged() throws {
        let jma = try JMAParser.forecast(data("jma-osaka", "json"), region: .osaka, now: now)
        let extra = WeatherSnapshot(region: .osaka, source: "Yahoo", issued: now.addingTimeInterval(-86400), fetched: now, days: [], slots: [])
        XCTAssertEqual(WeatherMerge.combine(primary: jma, supplement: extra).source, "JMA")
    }
    func testSparseSixDaysDoNotCreateRows() {
        let dates = [0, 1, 2, 4, 5, 6].map { JapanTime.calendar.date(byAdding: .day, value: $0, to: now)! }
        let value = WeatherSnapshot(region: .osaka, source: "JMA", issued: now, fetched: now, days: dates.map { ForecastDay(date: $0, high: 20, low: nil, probability: nil, condition: "晴れ") }, slots: [])
        XCTAssertEqual(value.sevenDays(from: now).count, 6)
        XCTAssertFalse(value.days.contains { $0.id == "2026-11-11" })
    }
    func testEmptyDailyRowsAreDiscarded() {
        let value = WeatherSnapshot(region: .osaka, source: "JMA", issued: now, fetched: now, days: [ForecastDay(date: now, high: nil, low: nil, probability: nil, condition: "")], slots: [])
        XCTAssertTrue(value.days.isEmpty); XCTAssertTrue(value.sevenDays(from: now).isEmpty)
    }
    func testJMAFiltersExtendedDatesAndIgnoresWindPayload() throws {
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: data("jma-osaka", "json")) as? [[String: Any]])
        var series = try XCTUnwrap(root[1]["timeSeries"] as? [[String: Any]])
        var areas = try XCTUnwrap(series[0]["areas"] as? [[String: Any]])
        series[0]["timeDefines"] = (0..<10).map { "2026-11-\(String(format: "%02d", 8+$0))T00:00:00+09:00" }
        areas[0]["weatherCodes"] = Array(repeating: "101", count: 10)
        areas[0]["winds"] = ["malformed": true]
        series[0]["areas"] = areas; root[1]["timeSeries"] = series
        let result = try JMAParser.forecast(JSONSerialization.data(withJSONObject: root), region: .osaka, now: now)
        XCTAssertEqual(result.days.count, 7); XCTAssertEqual(result.days.last?.id, "2026-11-14")
    }
    func testResilientYahooAndMergeRespectSevenDayLimit() throws {
        let jma = try JMAParser.forecast(data("jma-osaka", "json"), region: .osaka, now: now)
        let yahoo = try XCTUnwrap(YahooParser.resilientForecast(String(decoding: data("yahoo-osaka"), as: UTF8.self), region: .osaka, now: now))
        XCTAssertEqual(yahoo.days.count, 7)
        let merged = WeatherMerge.combine(primary: jma, supplement: yahoo)
        XCTAssertEqual(merged.days.count, 7)
        XCTAssertTrue(merged.days.allSatisfy { ForecastRange.contains($0.date, from: now) })
    }
    func testLegacyCacheDropsExtraDaysSlotsAndWindFields() throws {
        let original = WeatherSnapshot(region: .osaka, source: "JMA", issued: now, fetched: now, days: [], slots: [])
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        root["days"] = (0..<10).map { offset -> [String: Any] in
            ["date": now.addingTimeInterval(Double(offset)*86400).timeIntervalSinceReferenceDate, "high": 20, "condition": "晴れ", "windSpeed": 99]
        }
        root["slots"] = [["date": now.addingTimeInterval(8*86400).timeIntervalSinceReferenceDate, "condition": "雨", "durationHours": 3, "windDirection": "N"]]
        root["wind"] = ["speed": 99]
        let decoded = try JSONDecoder().decode(WeatherSnapshot.self, from: JSONSerialization.data(withJSONObject: root))
        XCTAssertEqual(decoded.days.count, 7); XCTAssertTrue(decoded.slots.isEmpty)
        let rewritten = String(decoding: try JSONEncoder().encode(decoded), as: UTF8.self)
        XCTAssertFalse(rewritten.contains("wind"))
        XCTAssertEqual(decoded.limited(to: now.addingTimeInterval(2*86400)).days.count, 5)
    }
    func testSevenDayBoundaryUsesJapanMidnight() {
        let late = JapanTime.iso("2026-12-31T23:59:00+09:00")!
        XCTAssertTrue(ForecastRange.contains(JapanTime.iso("2027-01-06T23:59:59+09:00")!, from: late))
        XCTAssertFalse(ForecastRange.contains(JapanTime.iso("2027-01-07T00:00:00+09:00")!, from: late))
    }
    func testDayEightRainCannotCreateNotification() {
        let slot = ForecastSlot(date: now.addingTimeInterval(7*86400), temperature: nil, rainMM: 20, probability: 100, condition: "雨", durationHours: 6)
        let value = WeatherSnapshot(region: .osaka, source: "JMA", issued: now, fetched: now, days: [], slots: [slot])
        XCTAssertTrue(value.slots.isEmpty); XCTAssertNil(ForecastRainPolicy.window(snapshot: value, now: now))
    }
}

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
}

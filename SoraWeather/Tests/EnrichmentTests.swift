import XCTest
@testable import SoraWeatherCore

final class EnrichmentTests: XCTestCase {
    func testOsakaSolarTimesAgainstNAOJNovemberTable() throws {
        let date = JapanTime.iso("2026-11-09T00:30:00+09:00")!
        let value = try XCTUnwrap(LocalAstronomy.calculate(date: date, latitude: 34.6833, longitude: 135.4833))
        // NAOJ Osaka table (0 m): 06:26 and 16:58 JST. Approximate horizon model.
        XCTAssertEqual(value.sunrise.timeIntervalSince(JapanTime.iso("2026-11-09T06:26:00+09:00")!), 0, accuracy: 240)
        XCTAssertEqual(value.sunset.timeIntervalSince(JapanTime.iso("2026-11-09T16:58:00+09:00")!), 0, accuracy: 240)
        XCTAssertEqual(JapanTime.key(value.sunrise), "2026-11-09")
    }
    func testPolarAndInvalidCoordinatesHideAstronomy() {
        let date = JapanTime.iso("2026-06-21T12:00:00+09:00")!
        XCTAssertNil(LocalAstronomy.calculate(date: date, latitude: 89, longitude: 0))
        XCTAssertNil(LocalAstronomy.calculate(date: date, latitude: .nan, longitude: 0))
        XCTAssertNil(LocalAstronomy.calculate(date: date, latitude: 35, longitude: 181))
    }
    func testKnownNewMoonAndFullMoon() throws {
        let new = try XCTUnwrap(LocalAstronomy.calculate(date: JapanTime.iso("2000-01-06T18:14:00Z")!, latitude: 34.69, longitude: 135.5))
        XCTAssertEqual(new.moonPhase, 0); XCTAssertLessThan(new.illumination, 0.02)
        let full = try XCTUnwrap(LocalAstronomy.calculate(date: JapanTime.iso("2020-10-31T15:00:00Z")!, latitude: 34.69, longitude: 135.5))
        XCTAssertEqual(full.moonPhase, 4); XCTAssertGreaterThan(full.illumination, 0.98)
    }
    func testSolarDateSurvivesJapanYearBoundary() throws {
        for text in ["2026-12-31T00:10:00+09:00", "2027-01-01T23:50:00+09:00"] {
            let date = JapanTime.iso(text)!
            let value = try XCTUnwrap(LocalAstronomy.calculate(date: date, latitude: 34.69, longitude: 135.5))
            XCTAssertEqual(JapanTime.key(value.sunrise), JapanTime.key(date))
            XCTAssertEqual(JapanTime.key(value.sunset), JapanTime.key(date))
        }
    }
    func testWarningSeverityKeepsSpecialWarningsAboveWarningsAndAdvisories() {
        func item(_ title: String) -> DisasterItem { DisasterItem(id: title, title: title, detail: "", issued: Date()) }
        XCTAssertEqual(WarningLevel.level(for: item("JMA 大雨特別警報 · 発表")), .special)
        XCTAssertEqual(WarningLevel.level(for: item("JMA 暴風警報 · 継続")), .warning)
        XCTAssertEqual(WarningLevel.level(for: item("JMA 大雨注意報 · 発表")), .advisory)
        XCTAssertTrue(WarningLevel.special > .warning); XCTAssertTrue(WarningLevel.warning > .advisory)
    }
}

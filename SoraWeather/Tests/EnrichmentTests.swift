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
    func testRadarRejectsBadTimeTraversalAndUnsupportedElement() throws {
        XCTAssertNil(RadarFrame(base: "../etc/passwd", valid: "20261108154000"))
        XCTAssertNil(RadarFrame(base: "20261308154000", valid: "20261108154000"))
        XCTAssertNil(RadarFrame(base: "20261108154000", valid: "20261108153500"))
        let data = Data(#"[{"basetime":"20261108154000","validtime":"20261108154000","elements":["hrpns"]},{"basetime":"bad","validtime":"bad","elements":["hrpns"]},{"basetime":"20261108154000","validtime":"20261108154000","elements":["thns"]}]"#.utf8)
        XCTAssertEqual(try RadarTimeline.parse(data).count, 1)
    }
    func testRadarUsesVerifiedTemplateAndEvenNativeZooms() throws {
        let frame = try XCTUnwrap(RadarFrame(base: "20261108154000", valid: "20261108154000"))
        XCTAssertEqual(frame.tileURL(z: 6, x: 56, y: 25)?.absoluteString, "https://www.jma.go.jp/bosai/jmatile/data/nowc/20261108154000/none/20261108154000/surf/hrpns/6/56/25.png")
        XCTAssertNil(frame.tileURL(z: 7, x: 112, y: 50))
        XCTAssertNil(frame.tileURL(z: 6, x: -1, y: 25))
        XCTAssertNil(frame.tileURL(z: 6, x: 64, y: 25))
    }
    func testRadarKeepsTwelveNeighborsAndNoInventedFrames() throws {
        let now = JapanTime.iso("2026-11-08T15:40:00Z")!
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(secondsFromGMT: 0); formatter.dateFormat = "yyyyMMddHHmmss"
        let history = (0..<37).compactMap { i -> RadarFrame? in let text = formatter.string(from: now.addingTimeInterval(Double(-i)*300)); return RadarFrame(base: text, valid: text) }
        let future = (1...12).compactMap { RadarFrame(base: "20261108154000", valid: formatter.string(from: now.addingTimeInterval(Double($0)*300))) }
        let frames = RadarTimeline.window(observed: history, predicted: future, now: now)
        XCTAssertEqual(frames.count, 25); XCTAssertEqual(frames.filter(\.forecast).count, 12)
        XCTAssertEqual(frames[12].date, now); XCTAssertEqual(Set(frames.map(\.date)).count, 25)
        XCTAssertEqual(RadarTimeline.window(observed: Array(history.prefix(2)), predicted: [], now: now).count, 2)
        XCTAssertTrue(RadarTimeline.window(observed: history, predicted: future, now: now.addingTimeInterval(3600)).isEmpty)
    }
    func testPalettePreservesJMAThresholdOrdering() {
        XCTAssertEqual(RadarPalette.source.count, RadarPalette.thresholds.count)
        XCTAssertEqual(RadarPalette.mapping[0xb40068], 0xffe563)
        XCTAssertNil(RadarPalette.mapping[0x000000])
        XCTAssertEqual(Set(RadarPalette.display).count, 8)
    }
    func testWarningSeverityKeepsSpecialWarningsAboveWarningsAndAdvisories() {
        func item(_ title: String) -> DisasterItem { DisasterItem(id: title, title: title, detail: "", issued: Date()) }
        XCTAssertEqual(WarningLevel.level(for: item("JMA 大雨特別警報 · 発表")), .special)
        XCTAssertEqual(WarningLevel.level(for: item("JMA 暴風警報 · 継続")), .warning)
        XCTAssertEqual(WarningLevel.level(for: item("JMA 大雨注意報 · 発表")), .advisory)
        XCTAssertTrue(WarningLevel.special > .warning); XCTAssertTrue(WarningLevel.warning > .advisory)
    }
}

import XCTest
final class SoraWeatherUITests: XCTestCase {
    func testPagingScrollingAndCityEditing() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-offline", "--ui-test-cities", "--ui-test-reset"]
        app.launch()
        dismissLocationPrompt()
        XCTAssertTrue(app.buttons["openCities"].waitForExistence(timeout: 20))
        assertVisible(app.staticTexts["cityTitle.osaka"])
        swipeCity(app, left: true); assertVisible(app.staticTexts["cityTitle.tokyo"])
        swipeCity(app, left: false); assertVisible(app.staticTexts["cityTitle.osaka"])
        app.swipeUp(); app.swipeUp(); app.swipeDown(); app.swipeDown()
        try openCities(app)
        XCTAssertTrue(app.textFields["citySearch"].waitForExistence(timeout: 10))
        let tokyo = app.buttons["cityRow.tokyo"]
        XCTAssertTrue(tokyo.waitForExistence(timeout: 10))
        tokyo.swipeLeft()
        let delete = app.buttons.matching(NSPredicate(format: "label IN %@", ["Delete", "删除", "刪除", "削除"])).firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5)); delete.tap()
        app.terminate()
        app.launchArguments = ["--ui-test-offline"]
        app.launch()
        XCTAssertTrue(app.buttons["openCities"].waitForExistence(timeout: 20))
        try openCities(app)
        XCTAssertTrue(app.textFields["citySearch"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["cityRow.osaka"].exists)
        XCTAssertFalse(app.buttons["cityRow.tokyo"].exists)
    }
    func testLocationChangeRestartsCurrentForecastTask() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reset", "--ui-test-offline", "--ui-test-location-change"]
        app.launch(); dismissLocationPrompt()
        assertVisible(app.staticTexts["cityTitle.osaka"])
        assertScope(app, region: "osaka")
        XCTAssertTrue(app.buttons["testLocationTokyo"].waitForExistence(timeout: 10))
        app.buttons["testLocationTokyo"].tap()
        assertVisible(app.staticTexts["cityTitle.tokyo"])
        assertScope(app, region: "tokyo")
        app.terminate()
        app.launchArguments = ["--ui-test-offline", "--ui-test-location-change"]
        app.launch()
        assertVisible(app.staticTexts["cityTitle.tokyo"])
        assertScope(app, region: "tokyo")
    }
    func testCityDismissalAstronomyWarningsAndRadarFailure() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reset", "--ui-test-offline", "--ui-test-warning", "--ui-test-radar-fail"]
        app.launch(); dismissLocationPrompt()
        assertVisible(app.staticTexts["cityTitle.osaka"])
        let start = app.staticTexts["cityTitle.osaka"].frame
        swipeCity(app, left: false)
        XCTAssertEqual(app.staticTexts["cityTitle.osaka"].frame.minX, start.minX, accuracy: 1)
        let edge = XCTAttachment(screenshot: app.screenshot()); edge.name = "single-city-no-black-edge"; edge.lifetime = .keepAlways; add(edge)
        XCTAssertTrue(app.buttons["warningBanner"].waitForExistence(timeout: 10))
        app.buttons["warningBanner"].tap()
        XCTAssertTrue(app.buttons["closeWarningDetails"].waitForExistence(timeout: 10)); app.buttons["closeWarningDetails"].tap()
        app.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)["astronomyCard"].waitForExistence(timeout: 10))
        try openCities(app)
        XCTAssertTrue(app.textFields["citySearch"].waitForExistence(timeout: 10))
        let list = XCTAttachment(screenshot: app.screenshot()); list.name = "unified-city-search"; list.lifetime = .keepAlways; add(list)
        let top = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
        top.press(forDuration: 0.01, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92)))
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.textFields["citySearch"])
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 10), .completed)
        XCTAssertTrue(app.buttons["openMap"].waitForExistence(timeout: 10)); app.buttons["openMap"].tap()
        let failed = app.staticTexts["testRadarState"]
        XCTAssertTrue(failed.waitForExistence(timeout: 15))
        let fallback = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'unavailable'"), object: failed)
        XCTAssertEqual(XCTWaiter.wait(for: [fallback], timeout: 20), .completed)
        XCTAssertTrue(app.descendants(matching: .any)["temperatureBubble"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.descendants(matching: .any)["rainLegend"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["rainPlayback"].exists)
        let map = XCTAttachment(screenshot: app.screenshot()); map.name = "radar-failure-retains-map-bubble"; map.lifetime = .keepAlways; add(map)
        app.buttons["closeMap"].tap()
    }
    func testLiveRadarPlayback() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reset", "--ui-test-offline", "--ui-test-radar-live"]
        app.launch(); dismissLocationPrompt()
        XCTAssertTrue(app.buttons["openMap"].waitForExistence(timeout: 20)); app.buttons["openMap"].tap()
        let playback = app.descendants(matching: .any)["rainPlayback"]
        let available = playback.waitForExistence(timeout: 90)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = available ? "live-jma-radar-playback" : "live-jma-radar-unavailable"; capture.lifetime = .keepAlways; add(capture)
        guard available else { throw XCTSkip("Live JMA rain tiles unavailable from CI; deterministic failure fallback is tested separately.") }
        XCTAssertTrue(app.descendants(matching: .any)["rainLegend"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["temperatureBubble"].exists)
        let timeline = app.sliders["rainTimeline"]
        XCTAssertTrue(timeline.exists); timeline.adjust(toNormalizedSliderPosition: 0.4)
        XCTAssertTrue(playback.exists)
        app.buttons["closeMap"].tap()
    }
    private func assertScope(_ app: XCUIApplication, region: String) {
        let value = app.staticTexts["forecastLoadScope"]
        XCTAssertTrue(value.waitForExistence(timeout: 10))
        let correct = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", region), object: value)
        XCTAssertEqual(XCTWaiter.wait(for: [correct], timeout: 10), .completed)
    }
    private func swipeCity(_ app: XCUIApplication, left: Bool) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.85 : 0.15, dy: 0.34))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.15 : 0.85, dy: 0.34))
        start.press(forDuration: 0.01, thenDragTo: end)
    }
    private func dismissLocationPrompt() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        if alert.waitForExistence(timeout: 3) {
            let deny = alert.buttons.matching(NSPredicate(format: "label IN %@", ["Don’t Allow", "Don't Allow", "不允许", "不允許", "許可しない"])).firstMatch
            if deny.exists { deny.tap() }
            let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: alert)
            XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 5), .completed)
        }
    }
    private func assertVisible(_ element: XCUIElement) {
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: element)
        let result = XCTWaiter.wait(for: [visible], timeout: 10)
        if result != .completed { print(XCUIApplication().debugDescription) }
        XCTAssertEqual(result, .completed)
    }
    private func openCities(_ app: XCUIApplication) throws {
        let buttons = app.buttons.matching(identifier: "openCities").allElementsBoundByIndex
        let button = try XCTUnwrap(buttons.first { $0.isHittable })
        button.tap()
    }
}

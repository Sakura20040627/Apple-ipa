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
    func testLivePullRefreshRemainsResponsive() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reset", "--ui-test-offline", "--ui-test-manual-network"]
        app.launch(); dismissLocationPrompt()
        assertVisible(app.staticTexts["cityTitle.osaka"])
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
        start.press(forDuration: 0.01, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)))
        let complete = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == 'complete'"), object: app.staticTexts["pullRefreshState"])
        XCTAssertEqual(XCTWaiter.wait(for: [complete], timeout: 100), .completed)
        try openCities(app)
        XCTAssertTrue(app.textFields["citySearch"].waitForExistence(timeout: 10))
        app.buttons["closeCities"].tap()
    }
    func testSafetyEmptyStateAndClose() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reset", "--ui-test-offline"]
        app.launch(); dismissLocationPrompt()
        XCTAssertTrue(app.buttons["openSafety"].waitForExistence(timeout: 20)); app.buttons["openSafety"].tap()
        XCTAssertTrue(app.staticTexts["safetyTitle"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["safetyEmpty"].exists)
        app.buttons["closeSafety"].tap()
        assertVisible(app.staticTexts["cityTitle.osaka"])
    }
    func testSafetyWarningsQuakesAndOtherCity() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reset", "--ui-test-offline", "--ui-test-warning", "--ui-test-cities"]
        app.launch(); dismissLocationPrompt()
        XCTAssertTrue(app.buttons["openSafety"].waitForExistence(timeout: 20)); app.buttons["openSafety"].tap()
        XCTAssertTrue(app.staticTexts["safetyTitle"].waitForExistence(timeout: 10))
        let row = app.buttons["warningRow.fixture-warning"]
        XCTAssertTrue(row.waitForExistence(timeout: 10)); row.tap()
        XCTAssertTrue(app.staticTexts["JMA UI fixture · 府県単位"].waitForExistence(timeout: 10))
        let quake = app.buttons["quakeRow.fixture-quake"]
        for _ in 0..<5 { if quake.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(quake.isHittable)
        let other = app.buttons["otherSafety.tokyo"]
        for _ in 0..<5 { if other.isHittable { break }; app.swipeDown() }
        XCTAssertTrue(other.isHittable); other.tap()
        assertVisible(app.staticTexts["cityTitle.tokyo"])
    }
    func testColdNotificationRouteWithLargestDynamicType() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-reset", "--ui-test-offline", "--ui-test-safety-route", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch(); dismissLocationPrompt()
        XCTAssertTrue(app.staticTexts["safetyTitle"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["safetyCityName"].label.contains("東京"))
        XCTAssertTrue(app.buttons["closeSafety"].isHittable)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.name = "accessible-safety-page"; capture.lifetime = .keepAlways; add(capture)
        app.buttons["closeSafety"].tap()
        assertVisible(app.staticTexts["cityTitle.tokyo"])
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

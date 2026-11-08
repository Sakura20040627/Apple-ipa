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
    private func swipeCity(_ app: XCUIApplication, left: Bool) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.85 : 0.15, dy: 0.25))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: left ? 0.15 : 0.85, dy: 0.25))
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
        XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 10), .completed)
    }
    private func openCities(_ app: XCUIApplication) throws {
        let buttons = app.buttons.matching(identifier: "openCities").allElementsBoundByIndex
        let button = try XCTUnwrap(buttons.first { $0.isHittable })
        button.tap()
    }
}

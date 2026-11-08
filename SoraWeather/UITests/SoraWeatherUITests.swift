import XCTest
final class SoraWeatherUITests: XCTestCase {
    func testPagingScrollingAndCityEditing() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-offline", "--ui-test-cities", "--ui-test-reset"]
        app.launch()
        XCTAssertTrue(app.buttons["openCities"].waitForExistence(timeout: 20))
        app.swipeLeft(); app.swipeRight()
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
    private func openCities(_ app: XCUIApplication) throws {
        let buttons = app.buttons.matching(identifier: "openCities").allElementsBoundByIndex
        let button = try XCTUnwrap(buttons.first { $0.isHittable })
        button.tap()
    }
}

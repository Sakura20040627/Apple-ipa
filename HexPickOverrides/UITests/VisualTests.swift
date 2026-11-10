import XCTest

@MainActor
final class VisualTests: XCTestCase {
    private func capture(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func app(theme: String, large: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-theme", theme, "-AppleLanguages", "(zh-Hans)", "-AppleLocale", "zh_CN"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["英雄"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "hero-")).firstMatch.waitForExistence(timeout: 30))
        return app
    }
    func testDiscoverSourcesAndCopyright() {
        let app = app(theme: "dark")
        app.tabBars.buttons["发现"].tap()
        XCTAssertTrue(app.navigationBars["发现"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["发现你的下一套玩法"].waitForExistence(timeout: 20))
        capture("08-discover-builds", app: app)
        app.buttons["图标映射报告"].tap()
        XCTAssertTrue(app.navigationBars["图标映射报告"].waitForExistence(timeout: 10))
        capture("09-icon-mapping-report", app: app)
        app.terminate()
    }
    func testDarkScreens() {
        let app = app(theme: "dark")
        capture("01-heroes-dark", app: app)
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "hero-")).firstMatch.tap()
        XCTAssertTrue(app.buttons["开始三选一"].waitForExistence(timeout: 10))
        capture("02-hero-detail-dark", app: app)
        app.tabBars.buttons["三选一"].tap()
        capture("03-compare-dark", app: app)
        app.tabBars.buttons["图鉴"].tap()
        XCTAssertTrue(app.navigationBars["海克斯图鉴"].waitForExistence(timeout: 10))
        capture("04-catalog-dark", app: app)
        app.tabBars.buttons["设置"].tap()
        capture("05-settings-dark", app: app)
        app.terminate()
    }
    func testLightAndLargestType() {
        var app = app(theme: "light")
        capture("06-heroes-light", app: app)
        app.terminate()
        app = self.app(theme: "dark", large: true)
        capture("07-heroes-accessibility-XXXL", app: app)
        app.terminate()
    }
}

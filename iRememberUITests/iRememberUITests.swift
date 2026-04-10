import XCTest

final class iRememberUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingShowsPrimaryActions() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Open your Messages archive"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open Messages Library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open Privacy & Security"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchesMainWindow() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}

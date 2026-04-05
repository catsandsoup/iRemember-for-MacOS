import XCTest

final class iRememberUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPaneControlsAndTimelineSurfacesAreInteractive() throws {
        let app = XCUIApplication()
        app.launch()

        let openLibraryButton = app.buttons["open-sample-library"]
        XCTAssertTrue(openLibraryButton.waitForExistence(timeout: 3))
        openLibraryButton.tap()

        let timelinePanel = app.otherElements["timeline-panel"]
        XCTAssertTrue(timelinePanel.waitForExistence(timeout: 5))

        XCTAssertTrue(app.scrollViews["timeline-scroll-surface"].exists || app.otherElements["timeline-scroll-surface"].exists)
        XCTAssertTrue(app.scrollViews["timeline-day-scrubber"].exists || app.otherElements["timeline-day-scrubber"].exists)

        let timelineToggle = app.buttons["timeline-toggle"]
        XCTAssertTrue(timelineToggle.exists)
        timelineToggle.tap()
        XCTAssertTrue(app.staticTexts["Timeline hidden. Expand to jump across weeks, months, and years."].waitForExistence(timeout: 2))
        timelineToggle.tap()

        let inspectorToggle = app.buttons["inspector-toggle"]
        XCTAssertTrue(inspectorToggle.exists)
        inspectorToggle.tap()
        XCTAssertFalse(app.otherElements["inspector-pane"].waitForExistence(timeout: 1))
        inspectorToggle.tap()
        XCTAssertTrue(app.otherElements["inspector-pane"].waitForExistence(timeout: 2))

        let sidebarToggle = app.buttons["sidebar-toggle"]
        XCTAssertTrue(sidebarToggle.exists)
        sidebarToggle.tap()
        XCTAssertFalse(app.otherElements["sidebar-pane"].waitForExistence(timeout: 1))
        sidebarToggle.tap()
        XCTAssertTrue(app.otherElements["sidebar-pane"].waitForExistence(timeout: 2))
    }
}

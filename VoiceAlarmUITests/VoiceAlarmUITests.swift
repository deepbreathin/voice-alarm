import XCTest

final class VoiceAlarmUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }

    func testTabsExist() {
        let app = launchApp()
        XCTAssertTrue(app.tabBars.buttons["Alarms"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Recordings"].exists)
    }

    func testAlarmsEmptyStateShowsAddButton() {
        let app = launchApp()
        app.tabBars.buttons["Alarms"].tap()
        // Either the empty-state CTA or the toolbar + button should be present.
        let addButton = app.buttons["addAlarmButton"]
        let emptyAdd = app.buttons["Add Alarm"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5) || emptyAdd.waitForExistence(timeout: 5))
    }

    func testCanOpenNewAlarmEditor() {
        let app = launchApp()
        app.tabBars.buttons["Alarms"].tap()
        if app.buttons["addAlarmButton"].waitForExistence(timeout: 5) {
            app.buttons["addAlarmButton"].tap()
        } else {
            app.buttons["Add Alarm"].tap()
        }
        // The editor should show a Save button (disabled until a recording is chosen).
        XCTAssertTrue(app.buttons["saveAlarmButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["selectRecordingButton"].exists)
    }

    func testCanNavigateToRecordingsAndOpenRecorder() {
        let app = launchApp()
        app.tabBars.buttons["Recordings"].tap()
        let recordButton = app.buttons["recordButton"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 5))
        recordButton.tap()
        XCTAssertTrue(app.buttons["recordToggle"].waitForExistence(timeout: 5))
    }
}

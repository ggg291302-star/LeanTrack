import XCTest

/// Walks through every main screen and saves a screenshot of each one.
/// The build machine collects them so the design can be checked without a Mac.
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-LTDemoData", "-LTUITest"]
        app.launch()
    }

    func testMainScreens() throws {
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 10))
        snapshot("01-Home")

        app.buttons["tab.diary"].tap()
        snapshot("02-Diary")

        app.buttons["tab.add"].tap()
        XCTAssertTrue(app.buttons["addFood.cancel"].waitForExistence(timeout: 5))
        snapshot("03-AddFood")
        app.buttons["addFood.cancel"].tap()

        app.buttons["tab.progress"].tap()
        snapshot("06-Progress")

        app.buttons["tab.more"].tap()
        snapshot("09-More")
    }

    /// Attaches the screenshot to the test result, and also writes it straight to
    /// the folder in LT_SCREENSHOT_DIR when the build machine provides one.
    private func snapshot(_ name: String) {
        // Give the screen a moment to settle.
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        let screenshot = XCUIScreen.main.screenshot()

        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        if let dir = ProcessInfo.processInfo.environment["LT_SCREENSHOT_DIR"], !dir.isEmpty {
            let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? screenshot.pngRepresentation.write(to: url)
        }
    }
}

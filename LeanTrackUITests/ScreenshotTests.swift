import XCTest

/// Walks through every main screen, checks the key flows work, and saves a screenshot of each.
/// The build machine collects them so the design can be checked without a Mac.
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// First launch: setup → plan → Home.
    func testOnboarding() throws {
        app.launchArguments += ["-LTFreshInstall", "-LTUITest"]
        app.launch()
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        snapshot("00a-Welcome")
        next.tap() // → About you
        snapshot("00b-AboutYou")
        next.tap() // → Goal
        next.tap() // → Activity
        next.tap() // → Plan
        XCTAssertTrue(app.staticTexts["onboarding.calories"].waitForExistence(timeout: 5))
        snapshot("00c-Plan")
        next.tap() // Start tracking
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 10))
        snapshot("00d-HomeEmpty")
    }

    /// Demo data: every tab and the main flows.
    func testMainScreens() throws {
        app.launchArguments += ["-LTDemoData", "-LTUITest"]
        app.launch()
        XCTAssertTrue(app.buttons["tab.home"].waitForExistence(timeout: 15))
        snapshot("01-Home")

        // "Today ▾" day picker
        app.buttons["home.dayPicker"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        snapshot("01b-DayPicker")
        app.buttons["Done"].tap()

        app.buttons["tab.diary"].tap()
        XCTAssertTrue(app.staticTexts["diary.dayTotal"].waitForExistence(timeout: 5))
        snapshot("02-Diary")

        // Add Food: tabs, search, detail, add
        app.buttons["tab.add"].tap()
        XCTAssertTrue(app.buttons["addFood.cancel"].waitForExistence(timeout: 5))
        snapshot("03-AddFood")
        app.buttons["addFood.tab.common"].tap()
        snapshot("03b-AddFood-Common")
        let search = app.textFields["addFood.search"]
        search.tap()
        search.typeText("chiken brest")
        let firstResult = app.staticTexts.matching(identifier: "foodRow.name").firstMatch
        XCTAssertTrue(firstResult.waitForExistence(timeout: 10))
        snapshot("03c-Search")
        firstResult.tap()
        let add = app.buttons["food.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        snapshot("04-FoodDetail")
        add.tap()
        XCTAssertTrue(app.buttons["addFood.cancel"].waitForExistence(timeout: 5))
        app.buttons["addFood.cancel"].tap()

        app.buttons["tab.progress"].tap()
        XCTAssertTrue(app.buttons["progress.logWeight"].waitForExistence(timeout: 5))
        snapshot("06-Progress")
        app.segmentedControls["progress.metric"].buttons["Calories"].tap()
        snapshot("06b-Progress-Calories")

        app.buttons["tab.more"].tap()
        XCTAssertTrue(app.buttons["more.bmi"].waitForExistence(timeout: 5))
        snapshot("09-More")

        open("more.bmi", expect: "bmi.value", name: "07-BMI")
        open("more.nutrition", expect: "nutrition.details", name: "08-Nutrition")
        open("more.goals", expect: "goals.calories", name: "10-Goals")

        app.buttons["more.recipes"].tap()
        let recipe = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'recipe.'")).firstMatch
        XCTAssertTrue(recipe.waitForExistence(timeout: 5))
        snapshot("05-Recipes")
        recipe.tap()
        XCTAssertTrue(app.buttons["recipe.log"].waitForExistence(timeout: 5))
        snapshot("05b-RecipeDetail")
        goBack()
        goBack()

        open("more.water", expect: "water.total", name: "11-Water")
        open("more.settings", expect: "settings.appearance", name: "12-Settings")
    }

    /// Opens a More row, waits for something on the new screen, takes a screenshot and goes back.
    private func open(_ row: String, expect identifier: String, name: String) {
        app.buttons[row].tap()
        let element = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: 5), "\(identifier) on \(row)")
        snapshot(name)
        goBack()
        XCTAssertTrue(app.buttons["more.bmi"].waitForExistence(timeout: 5))
    }

    private func goBack() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
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

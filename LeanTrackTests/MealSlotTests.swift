import XCTest
@testable import LeanTrack

final class MealSlotTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: hour, minute: minute))!
    }

    func testSuggestedMealByTimeOfDay() {
        XCTAssertEqual(MealSlot.suggested(for: date(hour: 3, minute: 59), calendar: calendar), .snacks)
        XCTAssertEqual(MealSlot.suggested(for: date(hour: 4), calendar: calendar), .breakfast)
        XCTAssertEqual(MealSlot.suggested(for: date(hour: 10, minute: 59), calendar: calendar), .breakfast)
        XCTAssertEqual(MealSlot.suggested(for: date(hour: 11), calendar: calendar), .lunch)
        XCTAssertEqual(MealSlot.suggested(for: date(hour: 14, minute: 59), calendar: calendar), .lunch)
        XCTAssertEqual(MealSlot.suggested(for: date(hour: 15), calendar: calendar), .snacks)
        XCTAssertEqual(MealSlot.suggested(for: date(hour: 17), calendar: calendar), .dinner)
        XCTAssertEqual(MealSlot.suggested(for: date(hour: 20, minute: 59), calendar: calendar), .dinner)
        XCTAssertEqual(MealSlot.suggested(for: date(hour: 21), calendar: calendar), .snacks)
    }
}

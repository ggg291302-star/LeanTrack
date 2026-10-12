import SwiftUI
import Observation

/// App-wide UI state shared by the tabs.
@Observable
final class AppState {
    /// The day shown on Home and in the Diary (start of day).
    var selectedDay: Date = Calendar.current.startOfDay(for: .now)
    var selectedTab: AppTab = .home
    /// Set to open Add Food for a meal (the center "+" or a Diary section's "+ Add Food").
    var addFoodMeal: MealSlot?
    /// Short confirmation shown at the bottom ("Added to Lunch").
    var toast: String?

    /// Set before the UI starts if the saved data couldn't be opened.
    static var startupError: String?

    func select(day: Date) {
        selectedDay = Calendar.current.startOfDay(for: day)
    }

    func showToast(_ message: String) {
        toast = message
        let shown = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            if self?.toast == shown { self?.toast = nil }
        }
    }
}

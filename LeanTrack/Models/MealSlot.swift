import Foundation

/// The four diary sections.
enum MealSlot: String, CaseIterable, Identifiable, Codable {
    case breakfast, lunch, dinner, snacks

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snacks: "Snacks"
        }
    }

    var systemImage: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.stars.fill"
        case .snacks: "carrot.fill"
        }
    }

    /// The meal the center "+" button opens, based on the time of day:
    /// 4:00–10:59 breakfast, 11:00–14:59 lunch, 15:00–16:59 snacks,
    /// 17:00–20:59 dinner, otherwise snacks.
    static func suggested(for date: Date, calendar: Calendar = .current) -> MealSlot {
        switch calendar.component(.hour, from: date) {
        case 4..<11: .breakfast
        case 11..<15: .lunch
        case 17..<21: .dinner
        default: .snacks
        }
    }
}

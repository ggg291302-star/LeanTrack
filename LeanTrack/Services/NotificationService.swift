import Foundation
import UserNotifications

/// Local reminders (no server, nothing leaves the phone). All are off until the owner turns them on.
enum Reminder: String, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, weighIn, water

    var id: String { rawValue }

    var title: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .weighIn: "Weigh-in"
        case .water: "Water"
        }
    }

    var message: String {
        switch self {
        case .breakfast: "Log your breakfast in LeanTrack."
        case .lunch: "Log your lunch in LeanTrack."
        case .dinner: "Log your dinner in LeanTrack."
        case .weighIn: "Time to weigh in. Same time each day gives the clearest trend."
        case .water: "Time for some water."
        }
    }

    /// Default time, minutes after midnight.
    var defaultMinutes: Int {
        switch self {
        case .breakfast: 8 * 60
        case .lunch: 12 * 60 + 30
        case .dinner: 18 * 60 + 30
        case .weighIn: 7 * 60
        case .water: 10 * 60
        }
    }

    var enabledKey: String { "reminder.\(rawValue).enabled" }
    var timeKey: String { "reminder.\(rawValue).minutes" }

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
    var minutes: Int { UserDefaults.standard.object(forKey: timeKey) as? Int ?? defaultMinutes }
}

enum NotificationService {
    /// Asks iOS for permission. Returns true if reminders can be shown.
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Replaces all LeanTrack reminders with the ones turned on in Settings.
    static func reschedule() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for reminder in Reminder.allCases where reminder.isEnabled {
            // Water repeats every 2 hours from the start time until 8 pm.
            let times = reminder == .water
                ? stride(from: reminder.minutes, through: 20 * 60, by: 120).map { $0 }
                : [reminder.minutes]
            for (index, minutes) in times.enumerated() {
                let content = UNMutableNotificationContent()
                content.title = reminder.title
                content.body = reminder.message
                content.sound = .default
                var date = DateComponents()
                date.hour = minutes / 60
                date.minute = minutes % 60
                let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
                center.add(UNNotificationRequest(identifier: "\(reminder.rawValue).\(index)", content: content, trigger: trigger))
            }
        }
    }

    static func turnAllOff() {
        for reminder in Reminder.allCases {
            UserDefaults.standard.removeObject(forKey: reminder.enabledKey)
            UserDefaults.standard.removeObject(forKey: reminder.timeKey)
        }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

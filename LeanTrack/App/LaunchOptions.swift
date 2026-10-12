import Foundation

/// Switches that only the automated tests can turn on, via launch arguments.
/// They're compiled out of Release builds (the IPA), so demo data can never
/// reach the real app on the phone.
enum LaunchOptions {
    /// `-LTDemoData`: use a throwaway in-memory store filled with a demo profile.
    static var isDemoMode: Bool { has("-LTDemoData") }

    /// `-LTFreshInstall`: use an empty in-memory store, to test first-launch setup.
    static var isFreshInstall: Bool { has("-LTFreshInstall") }

    /// `-LTUITest`: turn off animations so screenshots are stable.
    static var isUITest: Bool { has("-LTUITest") }

    private static func has(_ argument: String) -> Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(argument)
        #else
        false
        #endif
    }
}

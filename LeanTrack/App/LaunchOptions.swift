import Foundation

/// Switches that only the automated tests can turn on, via launch arguments.
/// They're compiled out of Release builds (the IPA), so demo data can never
/// reach the real app on the phone.
enum LaunchOptions {
    /// `-LTDemoData`: use a throwaway in-memory store filled with a demo profile.
    static var isDemoMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-LTDemoData")
        #else
        false
        #endif
    }

    /// `-LTUITest`: turn off animations so screenshots are stable.
    static var isUITest: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-LTUITest")
        #else
        false
        #endif
    }
}

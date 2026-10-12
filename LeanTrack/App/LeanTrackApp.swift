import SwiftUI

@main
struct LeanTrackApp: App {
    init() {
        if LaunchOptions.isUITest {
            UIView.setAnimationsEnabled(false)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}

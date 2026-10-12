import SwiftUI
import SwiftData

@main
struct LeanTrackApp: App {
    @State private var appState = AppState()
    private let container: ModelContainer

    init() {
        if LaunchOptions.isUITest {
            UIView.setAnimationsEnabled(false)
        }
        container = Self.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .environment(appState)
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }

    /// The real store lives in the app's private storage on the phone. Demo mode (UI tests only)
    /// uses a throwaway in-memory store, so demo data can never mix with real data.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema(AppSchema.models)
        if LaunchOptions.isDemoMode || LaunchOptions.isFreshInstall {
            let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            #if DEBUG
            if LaunchOptions.isDemoMode { DemoData.seed(into: container.mainContext) }
            #endif
            return container
        }
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration("LeanTrack"))
        } catch {
            // Never wipe the owner's data automatically. Fall back to a temporary store and show why.
            AppState.startupError = error.localizedDescription
            return try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
    }
}

/// Shows first-launch setup until the profile is complete, then the main app.
struct AppRoot: View {
    @Query private var profiles: [UserProfile]
    @AppStorage("appearance") private var appearance = Appearance.dark.rawValue

    var body: some View {
        Group {
            if let profile = profiles.first, profile.setupComplete {
                RootView()
            } else {
                OnboardingView()
            }
        }
        .preferredColorScheme(Appearance(rawValue: appearance)?.colorScheme)
        .alert("Couldn't open your saved data", isPresented: .constant(AppState.startupError != nil)) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("LeanTrack is running with temporary storage so nothing gets overwritten. Please send a screenshot of this message to get it fixed.\n\n\(AppState.startupError ?? "")")
        }
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, dark, light
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }
}

import SwiftUI

/// Hosts the four tab screens plus the custom tab bar.
/// Every tab stays alive while hidden, so switching tabs keeps your place.
struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        VStack(spacing: 0) {
            ZStack {
                ForEach(AppTab.allCases) { tab in
                    screen(for: tab)
                        .opacity(appState.selectedTab == tab ? 1 : 0)
                        .allowsHitTesting(appState.selectedTab == tab)
                        .accessibilityHidden(appState.selectedTab != tab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            LTTabBar(selection: $appState.selectedTab) {
                appState.addFoodMeal = MealSlot.suggested(for: Date())
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .overlay(alignment: .bottom) { toast }
        .fullScreenCover(item: $appState.addFoodMeal) { meal in
            AddFoodView(meal: meal, day: appState.selectedDay)
                .environment(appState)
        }
    }

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .home: HomeView()
        case .diary: DiaryView()
        case .progress: ProgressScreen()
        case .more: MoreView()
        }
    }

    @ViewBuilder
    private var toast: some View {
        if let message = appState.toast {
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.cardElevated, in: Capsule())
                .padding(.bottom, 90)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityAddTraits(.updatesFrequently)
        }
    }
}

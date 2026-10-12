import SwiftUI

/// Hosts the four tab screens plus the custom tab bar.
/// Every tab stays alive while hidden, so switching tabs keeps your place.
struct RootView: View {
    @State private var selection: AppTab = .home
    @State private var addFoodMeal: MealSlot?

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach(AppTab.allCases) { tab in
                    screen(for: tab)
                        .opacity(selection == tab ? 1 : 0)
                        .allowsHitTesting(selection == tab)
                        .accessibilityHidden(selection != tab)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            LTTabBar(selection: $selection) {
                addFoodMeal = MealSlot.suggested(for: Date())
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .sheet(item: $addFoodMeal) { meal in
            AddFoodView(meal: meal)
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
}

#Preview {
    RootView().preferredColorScheme(.dark)
}

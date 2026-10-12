import SwiftUI

/// Named `ProgressScreen` so it doesn't clash with SwiftUI's `ProgressView`.
struct ProgressScreen: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.cardSpacing) {
                    LTScreenTitle(title: "Progress")
                    LTComingSoon(
                        systemImage: "chart.line.uptrend.xyaxis",
                        title: "Progress",
                        message: "Weight, calorie and macro charts will show up here in Stage 4."
                    )
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    ProgressScreen().preferredColorScheme(.dark)
}

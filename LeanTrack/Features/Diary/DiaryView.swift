import SwiftUI

struct DiaryView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.cardSpacing) {
                    LTScreenTitle(title: "Food Diary")
                    LTComingSoon(
                        systemImage: "list.bullet.clipboard",
                        title: "Food Diary",
                        message: "Your week strip and Breakfast, Lunch, Dinner and Snacks will show up here in Stage 3."
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
    DiaryView().preferredColorScheme(.dark)
}

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                    header
                    LTComingSoon(
                        systemImage: "circle.dashed",
                        title: "Your day at a glance",
                        message: "The calorie ring, macros, meals and water will show up here in Stage 3."
                    )
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 4) {
                Text("Today")
                    .font(.title2.bold())
                Image(systemName: "chevron.down")
                    .font(.footnote.weight(.bold))
            }
            .foregroundStyle(Theme.textPrimary)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Today")
            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

#Preview {
    HomeView().preferredColorScheme(.dark)
}

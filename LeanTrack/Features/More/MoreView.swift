import SwiftUI

struct MoreView: View {
    private struct Entry: Identifiable {
        let systemImage: String
        let title: String
        var id: String { title }
    }

    private let tools: [Entry] = [
        Entry(systemImage: "figure", title: "BMI Calculator"),
        Entry(systemImage: "book", title: "Recipes"),
        Entry(systemImage: "chart.bar.fill", title: "Nutrition"),
        Entry(systemImage: "target", title: "Goals"),
        Entry(systemImage: "scalemass", title: "Weigh-ins"),
        Entry(systemImage: "drop.fill", title: "Water"),
        Entry(systemImage: "fork.knife", title: "Custom Foods & Meals"),
    ]

    private let app: [Entry] = [
        Entry(systemImage: "externaldrive", title: "Backup & Restore"),
        Entry(systemImage: "gearshape", title: "Settings"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    LTScreenTitle(title: "More")
                    section(tools)
                    section(app)
                    Text("These screens are coming in Stages 3–5.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func section(_ entries: [Entry]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                LTListRow(systemImage: entry.systemImage, title: entry.title)
                if index < entries.count - 1 {
                    LTRowDivider()
                }
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

#Preview {
    MoreView().preferredColorScheme(.dark)
}

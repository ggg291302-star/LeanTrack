import SwiftUI
import SwiftData

struct MoreView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        let profile = profiles.first
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    LTScreenTitle(title: "More")
                    if let profile {
                        HStack(spacing: 14) {
                            Image(systemName: "person.crop.circle.fill").font(.system(size: 44)).foregroundStyle(Theme.accent)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name.isEmpty ? "You" : profile.name).font(.headline).foregroundStyle(Theme.textPrimary)
                                Text("\(profile.calorieGoal.formatted()) cal goal · BMI \(Format.number(profile.bmi, decimals: 1))")
                                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                        }
                        .padding(16)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                    }
                    VStack(spacing: 0) {
                        row("figure", "BMI Calculator", id: "bmi") { BMICalculatorView() }
                        LTRowDivider()
                        row("book", "Recipes", id: "recipes") { RecipesView() }
                        LTRowDivider()
                        row("chart.bar.fill", "Nutrition", id: "nutrition") { NutritionView() }
                        LTRowDivider()
                        row("target", "Goals", id: "goals") { GoalsView() }
                        LTRowDivider()
                        row("scalemass", "Weigh-ins", id: "weighIns") { WeighInsView() }
                        LTRowDivider()
                        row("drop.fill", "Water", id: "water") { WaterView() }
                        LTRowDivider()
                        row("fork.knife", "Custom Foods & Meals", id: "myFoods") { MyFoodsView() }
                    }
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                    VStack(spacing: 0) {
                        row("externaldrive", "Backup & Restore", id: "backup") { BackupView() }
                        LTRowDivider()
                        row("gearshape", "Settings", id: "settings") { SettingsView() }
                    }
                    .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                    Text("LeanTrack gives general nutrition information, not medical advice.")
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

    private func row<Destination: View>(_ icon: String, _ title: String, id: String, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink(destination: destination) {
            LTListRow(systemImage: icon, title: title)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("more.\(id)")
    }
}

#Preview {
    MoreView().preferredColorScheme(.dark)
}

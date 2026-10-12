import SwiftUI
import SwiftData

/// Small water tracker with quick-add buttons.
struct WaterCard: View {
    let day: Date
    let profile: UserProfile
    @Environment(\.modelContext) private var context
    @Query private var water: [WaterEntry]

    init(day: Date, profile: UserProfile) {
        self.day = day
        self.profile = profile
        let start = Calendar.current.startOfDay(for: day)
        _water = Query(filter: #Predicate<WaterEntry> { $0.day == start }, sort: \.createdAt)
    }

    /// One cup: 8 US fl oz, or 250 ml in metric.
    private var cupMl: Double { profile.volumeUnit == .milliliters ? 250 : UnitConversion.milliliters(fromFluidOunces: 8) }

    var body: some View {
        let total = water.reduce(0) { $0 + $1.milliliters }
        LTCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "drop.fill").foregroundStyle(Theme.water).accessibilityHidden(true)
                    Text("Water").font(.headline).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(Format.volume(ml: total, unit: profile.volumeUnit)) of \(Format.volume(ml: profile.waterGoalMl, unit: profile.volumeUnit))")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .accessibilityIdentifier("water.total")
                }
                LTProgressBar(value: profile.waterGoalMl > 0 ? total / profile.waterGoalMl : 0, color: Theme.water, height: 8)
                HStack(spacing: 8) {
                    waterButton(ml: cupMl, label: profile.volumeUnit == .milliliters ? "+250 ml" : "+8 fl oz", id: "water.addCup")
                    waterButton(ml: cupMl * 2, label: profile.volumeUnit == .milliliters ? "+500 ml" : "+16 fl oz", id: "water.addTwo")
                    Spacer()
                    Button {
                        if let last = water.last { context.delete(last); try? context.save() }
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .frame(width: 40, height: 34)
                            .background(Theme.cardElevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .disabled(water.isEmpty)
                    .accessibilityLabel("Undo last water")
                }
            }
        }
    }

    private func waterButton(ml: Double, label: String, id: String) -> some View {
        Button {
            context.insert(WaterEntry(milliliters: ml, day: day))
            try? context.save()
        } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Theme.cardElevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .accessibilityLabel("Add \(label.dropFirst()) of water")
        .accessibilityIdentifier(id)
    }
}

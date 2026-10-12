import SwiftUI
import SwiftData

/// Water tracker: one glass per cup of the daily goal. Tap an empty glass to fill up to it,
/// tap "+1 cup" for one more, or undo the last one.
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
    private var cupLabel: String { profile.volumeUnit == .milliliters ? "250 ml" : "8 fl oz" }

    var body: some View {
        let total = water.reduce(0) { $0 + $1.milliliters }
        let goalCups = max(1, min(16, Int((profile.waterGoalMl / cupMl).rounded(.up))))
        let cups = Int((total / cupMl + 0.01).rounded(.down))
        LTCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "drop.fill").foregroundStyle(Theme.water).accessibilityHidden(true)
                    Text("Water").font(.headline).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(cups) of \(goalCups) cups · \(Format.volume(ml: total, unit: profile.volumeUnit))")
                        .font(.subheadline)
                        .foregroundStyle(cups >= goalCups ? Theme.water : Theme.textSecondary)
                        .accessibilityIdentifier("water.total")
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: min(goalCups, 8)), spacing: 8) {
                    ForEach(0..<goalCups, id: \.self) { index in
                        Button {
                            if index >= cups { add(cups: index + 1 - cups) } else { undo() }
                        } label: {
                            Image(systemName: index < cups ? "drop.fill" : "drop")
                                .font(.title2)
                                .foregroundStyle(index < cups ? Theme.water : Theme.textSecondary)
                                .frame(maxWidth: .infinity, minHeight: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(index < cups ? "Cup \(index + 1), drunk. Tap to undo the last cup" : "Cup \(index + 1). Tap to fill up to here")
                    }
                }
                HStack(spacing: 10) {
                    Button { add(cups: 1) } label: {
                        Label("1 cup (\(cupLabel))", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Theme.water.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .foregroundStyle(Theme.water)
                    .accessibilityIdentifier("water.addCup")
                    Button { undo() } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .frame(width: 48, height: 40)
                            .background(Theme.cardElevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .disabled(water.isEmpty)
                    .accessibilityLabel("Undo last water")
                }
            }
        }
    }

    private func add(cups: Int) {
        guard cups > 0 else { return }
        for i in 0..<cups {
            let entry = WaterEntry(milliliters: cupMl, day: day)
            entry.createdAt = Date().addingTimeInterval(Double(i) * 0.001)
            context.insert(entry)
        }
        try? context.save()
    }

    private func undo() {
        if let last = water.last {
            context.delete(last)
            try? context.save()
        }
    }
}

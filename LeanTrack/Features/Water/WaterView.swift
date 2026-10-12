import SwiftUI
import SwiftData
import Charts

/// More → Water: today's water, custom amounts, the log, and the last 7 days.
struct WaterView: View {
    @Environment(AppState.self) private var appState
    @Query private var profiles: [UserProfile]

    var body: some View {
        ScrollView {
            if let profile = profiles.first {
                WaterDayContent(day: appState.selectedDay, profile: profile)
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.bottom, 24)
            }
        }
        .background(Theme.background)
        .navigationTitle("Water")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WaterDayContent: View {
    let day: Date
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var context
    @Query private var today: [WaterEntry]
    @Query private var week: [WaterEntry]
    @State private var custom: Double = 0

    init(day: Date, profile: UserProfile) {
        self.day = day
        self.profile = profile
        let start = Calendar.current.startOfDay(for: day)
        let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: start) ?? start
        _today = Query(filter: #Predicate<WaterEntry> { $0.day == start }, sort: \.createdAt, order: .reverse)
        _week = Query(filter: #Predicate<WaterEntry> { $0.day >= weekStart && $0.day <= start })
    }

    var body: some View {
        let unit = profile.volumeUnit
        VStack(alignment: .leading, spacing: Theme.cardSpacing) {
            Text(Format.dayTitle(day)).font(.title2.bold()).foregroundStyle(Theme.textPrimary).padding(.top, 8)
            WaterCard(day: day, profile: profile)
            LTCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Add a different amount").font(.headline).foregroundStyle(Theme.textPrimary)
                    HStack {
                        NumberField(placeholder: unit.title, value: $custom, unit: unit.title, decimals: 0, width: 90)
                        Spacer()
                        Button("Add") {
                            let ml = unit == .milliliters ? custom : UnitConversion.milliliters(fromFluidOunces: custom)
                            guard ml > 0 else { return }
                            context.insert(WaterEntry(milliliters: ml, day: day))
                            try? context.save()
                            custom = 0
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(custom <= 0)
                    }
                }
            }
            if !today.isEmpty {
                LTSectionHeader(title: "Log")
                VStack(spacing: 0) {
                    ForEach(today) { entry in
                        HStack {
                            Text(entry.createdAt.formatted(date: .omitted, time: .shortened)).foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Text(Format.volume(ml: entry.milliliters, unit: unit)).foregroundStyle(Theme.textPrimary)
                            Button {
                                context.delete(entry)
                                try? context.save()
                            } label: { Image(systemName: "trash").foregroundStyle(Theme.danger) }
                            .buttonStyle(.plain)
                            .padding(.leading, 12)
                            .accessibilityLabel("Delete")
                        }
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        if entry.id != today.last?.id { LTRowDivider(leadingInset: 16) }
                    }
                }
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            }
            LTSectionHeader(title: "Last 7 days")
            let byDay = Dictionary(grouping: week, by: \.day).mapValues { $0.reduce(0) { $0 + $1.milliliters } }
            let days = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0 - 6, to: Calendar.current.startOfDay(for: day)) }
            let toUnit: (Double) -> Double = { unit == .milliliters ? $0 : UnitConversion.fluidOunces(fromMilliliters: $0) }
            Chart {
                ForEach(days, id: \.self) { d in
                    BarMark(x: .value("Day", d.formatted(.dateTime.weekday(.abbreviated))), y: .value("Water", toUnit(byDay[d] ?? 0)))
                        .foregroundStyle(Theme.water)
                }
                RuleMark(y: .value("Goal", toUnit(profile.waterGoalMl)))
                    .foregroundStyle(Theme.textSecondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }
            .frame(height: 180)
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            LTCard {
                HStack {
                    Text("Daily goal").foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Stepper(Format.volume(ml: profile.waterGoalMl, unit: unit), value: $profile.waterGoalMl, in: 500...6000,
                            step: unit == .milliliters ? 100 : UnitConversion.milliliters(fromFluidOunces: 4))
                        .fixedSize()
                }
            }
            Text("The National Academies suggest about 2.7 L (91 oz) of total water a day for women and 3.7 L (125 oz) for men, from all drinks and food. About 80% usually comes from drinks, which is where LeanTrack's default goal comes from.")
                .font(.caption).foregroundStyle(Theme.textSecondary)
        }
        .onChange(of: profile.waterGoalMl) { try? context.save() }
    }
}

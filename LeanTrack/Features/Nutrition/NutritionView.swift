import SwiftUI
import SwiftData
import Charts

/// More → Nutrition: Calories (week chart with goal line), Nutrients (every nutrient vs goals),
/// and Macros (split vs targets) for one day.
struct NutritionView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case calories, nutrients, macros
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    @Environment(AppState.self) private var appState
    @Query private var profiles: [UserProfile]
    @State private var tab: Tab = .calories
    @State private var day: Date?

    var body: some View {
        let current = day ?? appState.selectedDay
        ScrollView {
            VStack(spacing: Theme.cardSpacing) {
                Picker("Show", selection: $tab) { ForEach(Tab.allCases) { Text($0.title).tag($0) } }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("nutrition.tab")
                HStack {
                    Button { shift(-1, from: current) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 36) }
                        .accessibilityLabel("Previous day")
                    Spacer()
                    Text(current.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.headline).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Button { shift(1, from: current) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 36) }
                        .accessibilityLabel("Next day")
                }
                if let profile = profiles.first {
                    NutritionDayContent(day: current, profile: profile, tab: $tab) { day = $0 }
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .navigationTitle("Nutrition")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func shift(_ days: Int, from date: Date) {
        day = Calendar.current.date(byAdding: .day, value: days, to: date).map { Calendar.current.startOfDay(for: $0) }
    }
}

private struct NutritionDayContent: View {
    let day: Date
    let profile: UserProfile
    @Binding var tab: NutritionView.Tab
    let select: (Date) -> Void
    @Query private var weekEntries: [DiaryEntry]
    @Query private var exercise: [ExerciseEntry]
    @State private var selectedLabel: String?
    private let weekDays: [Date]

    init(day: Date, profile: UserProfile, tab: Binding<NutritionView.Tab>, select: @escaping (Date) -> Void) {
        self.day = Calendar.current.startOfDay(for: day)
        self.profile = profile
        self._tab = tab
        self.select = select
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday, like the design
        let start = cal.dateInterval(of: .weekOfYear, for: day)?.start ?? Calendar.current.startOfDay(for: day)
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }.map { Calendar.current.startOfDay(for: $0) }
        weekDays = days
        let first = days.first ?? start
        let end = cal.date(byAdding: .day, value: 7, to: first) ?? first
        _weekEntries = Query(filter: #Predicate<DiaryEntry> { $0.day >= first && $0.day < end })
        let dayStart = Calendar.current.startOfDay(for: day)
        _exercise = Query(filter: #Predicate<ExerciseEntry> { $0.day == dayStart })
    }

    private func label(_ d: Date) -> String { d.formatted(.dateTime.weekday(.abbreviated)) }

    var body: some View {
        let todays = weekEntries.filter { $0.day == day }
        let totals = DayTotals(todays)
        switch tab {
        case .calories: calories(totals: totals, todays: todays)
        case .nutrients: nutrients(totals: totals)
        case .macros: macros(totals: totals)
        }
    }

    // MARK: Calories

    @ViewBuilder
    private func calories(totals: DayTotals, todays: [DiaryEntry]) -> some View {
        let sums = DailySummary.byDay(weekEntries)
        let goal = Double(profile.calorieGoal)
        Chart {
            ForEach(weekDays, id: \.self) { d in
                BarMark(x: .value("Day", label(d)), y: .value("Calories", sums[d]?.kcal ?? 0), width: .ratio(0.6))
                    .foregroundStyle(d == day ? Theme.accent : Theme.accent.opacity(0.4))
                    .cornerRadius(3)
            }
            RuleMark(y: .value("Goal", goal))
                .foregroundStyle(Theme.textSecondary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
        }
        .chartXSelection(value: $selectedLabel)
        .onChange(of: selectedLabel) { _, value in
            if let value, let d = weekDays.first(where: { label($0) == value }) { select(d) }
        }
        .frame(height: 220)
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .accessibilityLabel("Calories this week")

        let burned = exercise.reduce(0) { $0 + $1.kcal }
        VStack(spacing: 0) {
            row("Calories", "\(Format.calories(totals.kcal))", bold: true)
            LTRowDivider(leadingInset: 16)
            row("Daily Goal", profile.calorieGoal.formatted())
            if burned > 0 {
                LTRowDivider(leadingInset: 16)
                row("Exercise\(profile.exerciseAddsBack ? " (added back)" : "")", "\(Format.calories(burned))")
            }
            LTRowDivider(leadingInset: 16)
            let remaining = NutritionMath.remaining(goal: profile.calorieGoal, eaten: totals.kcal, exercise: burned, addExercise: profile.exerciseAddsBack)
            row(remaining < 0 ? "Over" : "Remaining", Format.calories(abs(remaining)))
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))

        VStack(spacing: 0) {
            ForEach(MealSlot.allCases) { meal in
                let kcal = todays.filter { $0.meal == meal }.reduce(0) { $0 + $1.kcal }
                row(meal.title, "\(Format.calories(kcal)) cal · \(totals.kcal > 0 ? Int((kcal / totals.kcal * 100).rounded()) : 0)%")
                if meal != .snacks { LTRowDivider(leadingInset: 16) }
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))

        Button("View Nutrition Details") { tab = .nutrients }
            .font(.body.weight(.semibold))
            .padding(.top, 4)
            .accessibilityIdentifier("nutrition.details")
    }

    private func row(_ title: String, _ value: String, bold: Bool = false) -> some View {
        HStack {
            Text(title).font(bold ? .headline : .body).foregroundStyle(bold ? Theme.textPrimary : Theme.textSecondary)
            Spacer()
            Text(value).font(bold ? .headline : .body).foregroundStyle(Theme.textPrimary).monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: Nutrients

    @ViewBuilder
    private func nutrients(totals: DayTotals) -> some View {
        if totals.entryCount == 0 {
            LTComingSoon(systemImage: "list.bullet.rectangle", title: "Nothing logged on this day", message: "Log food to see every nutrient compared with your goals.")
        } else {
            NutrientFactsCard(nutrients: totals.nutrients, title: "Totals for the day", goals: goalMap, missing: totals.missing, showAll: true)
        }
    }

    private var goalMap: [String: Double] {
        let macros = profile.macroGoals
        var goals: [String: Double] = ["protein": macros.protein, "carbs": macros.carbs, "fat": macros.fat, "fiber": profile.fiberGoalG]
        for (key, value) in profile.extraGoals { goals[key] = value }
        return goals
    }

    // MARK: Macros

    @ViewBuilder
    private func macros(totals: DayTotals) -> some View {
        let goals = profile.macroGoals
        let shares = NutritionMath.macroShares(protein: totals.protein, carbs: totals.carbs, fat: totals.fat)
        let rounded = NutritionMath.roundedTo100([shares.protein, shares.carbs, shares.fat])
        LTCard {
            HStack(spacing: 20) {
                ZStack {
                    MacroDonut(protein: totals.protein, carbs: totals.carbs, fat: totals.fat)
                    VStack(spacing: 0) {
                        Text(Format.calories(totals.kcal)).font(.title2.bold()).foregroundStyle(Theme.textPrimary)
                        Text("cal").font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
                .frame(width: 120, height: 120)
                VStack(alignment: .leading, spacing: 10) {
                    legend("Protein", rounded[0], profile.proteinPercent, Theme.protein)
                    legend("Carbs", rounded[1], profile.carbsPercent, Theme.carbs)
                    legend("Fat", rounded[2], profile.fatPercent, Theme.fat)
                }
                Spacer(minLength: 0)
            }
        }
        LTCard {
            VStack(spacing: 14) {
                macroBar("Protein", totals.protein, goals.protein, Theme.protein)
                macroBar("Carbs", totals.carbs, goals.carbs, Theme.carbs)
                macroBar("Fat", totals.fat, goals.fat, Theme.fat)
                macroBar("Fiber", totals.nutrients.fiber ?? 0, profile.fiberGoalG, Theme.textSecondary)
            }
        }
        Text("Percents are each macro's share of the calories from protein, carbs and fat (4, 4 and 9 calories per gram), so they always add up to 100%.")
            .font(.caption).foregroundStyle(Theme.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legend(_ name: String, _ actual: Int, _ target: Double, _ color: Color) -> some View {
        HStack(spacing: 8) {
            MacroDot(color: color, size: 12)
            Text(name).foregroundStyle(Theme.textPrimary)
            Spacer()
            Text("\(actual)%").font(.headline).foregroundStyle(color)
            Text("/ \(Format.number(target))%").font(.caption).foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func macroBar(_ name: String, _ grams: Double, _ goal: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(Format.grams(grams)) / \(Format.number(goal)) g").foregroundStyle(Theme.textSecondary).monospacedDigit()
            }
            .font(.subheadline)
            LTProgressBar(value: goal > 0 ? grams / goal : 0, color: color, height: 8)
        }
        .accessibilityElement(children: .combine)
    }
}

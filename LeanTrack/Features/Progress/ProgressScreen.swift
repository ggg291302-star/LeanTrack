import SwiftUI
import SwiftData
import Charts

/// Named `ProgressScreen` so it doesn't clash with SwiftUI's `ProgressView`.
struct ProgressScreen: View {
    enum Metric: String, CaseIterable, Identifiable {
        case weight, calories, macros
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
    }

    enum ChartRange: String, CaseIterable, Identifiable {
        case week = "1W", month = "1M", threeMonths = "3M", sixMonths = "6M", year = "1Y"
        var id: String { rawValue }
        var days: Int {
            switch self {
            case .week: 7
            case .month: 30
            case .threeMonths: 91
            case .sixMonths: 182
            case .year: 365
            }
        }
        func start(from today: Date = .now) -> Date {
            let cal = Calendar.current
            return cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: today)) ?? today
        }
    }

    @Query private var profiles: [UserProfile]
    @State private var metric: Metric = .weight
    @State private var range: ChartRange = .month
    @State private var addingWeight = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.cardSpacing) {
                    LTScreenTitle(title: "Progress")
                    Picker("Chart", selection: $metric) {
                        ForEach(Metric.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("progress.metric")
                    HStack {
                        ForEach(ChartRange.allCases) { r in
                            Button(r.rawValue) { range = r }
                                .font(.subheadline.weight(range == r ? .semibold : .regular))
                                .foregroundStyle(range == r ? Theme.textPrimary : Theme.textSecondary)
                                .frame(maxWidth: .infinity, minHeight: 34)
                                .background(range == r ? Theme.cardElevated : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .accessibilityAddTraits(range == r ? [.isSelected] : [])
                        }
                    }
                    if let profile = profiles.first {
                        switch metric {
                        case .weight: WeightProgress(range: range, profile: profile, addWeight: { addingWeight = true })
                        case .calories: CaloriesProgress(range: range, profile: profile)
                        case .macros: MacrosProgress(range: range, profile: profile)
                        }
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $addingWeight) { AddWeighInSheet(entry: nil) }
        }
    }
}

/// Two numbers side by side under a chart ("Average | Change").
struct StatPair: View {
    let leftTitle: String
    let leftValue: String
    let rightTitle: String
    let rightValue: String
    var rightColor: Color = Theme.textPrimary

    var body: some View {
        HStack(spacing: 0) {
            stat(leftTitle, leftValue, Theme.textPrimary)
            Divider().frame(height: 44)
            stat(rightTitle, rightValue, rightColor)
        }
        .padding(.vertical, 14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private func stat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.subheadline).foregroundStyle(Theme.textSecondary)
            Text(value).font(.title3.bold()).foregroundStyle(color).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Weight

private struct WeightProgress: View {
    let range: ProgressScreen.ChartRange
    let profile: UserProfile
    let addWeight: () -> Void
    @Query(sort: \WeightEntry.date) private var all: [WeightEntry]

    var body: some View {
        let unit = profile.weightUnit
        let start = range.start()
        let points = all.map { WeightTrend.Point(date: $0.date, kg: $0.weightKg) }
        let shown = points.filter { $0.date >= start }
        let trend = WeightTrend.movingAverage(points).filter { $0.date >= start }
        let toUnit: (Double) -> Double = { unit == .kg ? $0 : UnitConversion.pounds(fromKilograms: $0) }
        let goal = toUnit(profile.goalWeightKg)

        if shown.isEmpty {
            LTComingSoon(systemImage: "scalemass", title: "No weigh-ins in this range",
                         message: "Log your weight to see your trend. Weighing at the same time each day (like after waking up) gives the clearest picture.")
        } else {
            let values = shown.map { toUnit($0.kg) }
            let lower = ((values.min() ?? 0) - 2).rounded(.down)
            let upper = ((values.max() ?? 0) + 2).rounded(.up)
            Chart {
                ForEach(shown, id: \.self) { p in
                    AreaMark(x: .value("Date", p.date), yStart: .value("Base", lower), yEnd: .value("Weight", toUnit(p.kg)))
                        .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.35), Theme.accent.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("Date", p.date), y: .value("Weight", toUnit(p.kg)), series: .value("Series", "Weigh-ins"))
                        .foregroundStyle(Theme.accent)
                        .symbol(Circle())
                        .interpolationMethod(.monotone)
                }
                if shown.count >= 3 {
                    ForEach(trend, id: \.self) { p in
                        LineMark(x: .value("Date", p.date), y: .value("Weight", toUnit(p.kg)), series: .value("Series", "7-day trend"))
                            .foregroundStyle(Theme.textSecondary)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    }
                }
                if profile.goal != .maintain && goal >= lower && goal <= upper {
                    RuleMark(y: .value("Goal", goal))
                        .foregroundStyle(Theme.protein)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                        .annotation(position: .top, alignment: .leading) { Text("Goal").font(.caption2).foregroundStyle(Theme.protein) }
                }
            }
            .chartYScale(domain: lower...upper)
            .frame(height: 230)
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .accessibilityLabel("Weight chart, \(shown.count) weigh-ins")

            let average = values.reduce(0, +) / Double(values.count)
            let change = (values.last ?? 0) - (values.first ?? 0)
            let goodDirection = profile.goal == .gain ? change > 0 : change < 0
            StatPair(leftTitle: "Average", leftValue: "\(Format.number(average, decimals: 1)) \(unit.rawValue)",
                     rightTitle: "Change", rightValue: "\(change > 0 ? "+" : "")\(Format.number(change, decimals: 1)) \(unit.rawValue)",
                     rightColor: abs(change) < 0.05 || profile.goal == .maintain ? Theme.textPrimary : (goodDirection ? Theme.positive : Theme.fat))
        }

        Button(action: addWeight) { Label("Log Weight", systemImage: "plus") }
            .buttonStyle(LTPrimaryButtonStyle())
            .accessibilityIdentifier("progress.logWeight")

        GoalProgressCard(profile: profile, points: points)

        NavigationLink { WeighInsView() } label: {
            LTListRow(systemImage: "list.bullet", title: "All weigh-ins", value: "\(all.count)")
                .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Start → now → goal, the trend per week, and when the goal might be reached.
struct GoalProgressCard: View {
    let profile: UserProfile
    let points: [WeightTrend.Point]

    var body: some View {
        let unit = profile.weightUnit
        let rate = WeightTrend.kgPerWeek(points)
        LTCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Goal").font(.headline).foregroundStyle(Theme.textPrimary)
                HStack {
                    column("Start", Format.weight(kg: profile.startWeightKg, unit: unit))
                    column("Now", Format.weight(kg: profile.currentWeightKg, unit: unit))
                    column("Goal", profile.goal == .maintain ? "Maintain" : Format.weight(kg: profile.goalWeightKg, unit: unit))
                }
                if profile.goal != .maintain {
                    let total = profile.goalWeightKg - profile.startWeightKg
                    let done = profile.currentWeightKg - profile.startWeightKg
                    let fraction = total != 0 ? max(0, min(1, done / total)) : 0
                    LTProgressBar(value: fraction, color: Theme.protein, height: 8)
                    Text("\(Int((fraction * 100).rounded()))% of the way · \(Format.weight(kg: abs(profile.goalWeightKg - profile.currentWeightKg), unit: unit)) to go")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                }
                if let rate {
                    let perWeek = unit == .kg ? rate : UnitConversion.pounds(fromKilograms: rate)
                    Text("Trend: \(perWeek > 0 ? "+" : "")\(Format.number(perWeek, decimals: 1)) \(unit.rawValue) per week (last 4 weeks)")
                        .font(.subheadline).foregroundStyle(Theme.textPrimary)
                    if profile.goal != .maintain {
                        if let date = WeightTrend.projectedDate(currentKg: profile.currentWeightKg, goalKg: profile.goalWeightKg, kgPerWeek: rate) {
                            Text("At this pace you'd reach your goal around \(date.formatted(date: .abbreviated, time: .omitted)).")
                                .font(.subheadline).foregroundStyle(Theme.textSecondary)
                        } else {
                            Text("Your recent trend isn't heading toward your goal yet.").font(.subheadline).foregroundStyle(Theme.textSecondary)
                        }
                    }
                } else {
                    Text("Log at least 3 weigh-ins over a week or more to see your trend.").font(.subheadline).foregroundStyle(Theme.textSecondary)
                }
                if profile.goal != .maintain, profile.paceLbPerWeek > 0 {
                    let planKg = UnitConversion.kilograms(fromPounds: profile.paceLbPerWeek) * (profile.goal == .lose ? -1 : 1)
                    if let planned = WeightTrend.projectedDate(currentKg: profile.currentWeightKg, goalKg: profile.goalWeightKg, kgPerWeek: planKg) {
                        Text("Your plan (\(Format.number(profile.paceLbPerWeek, decimals: 2)) lb a week) reaches it around \(planned.formatted(date: .abbreviated, time: .omitted)).")
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
    }

    private func column(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundStyle(Theme.textSecondary)
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Calories

private struct CaloriesProgress: View {
    let range: ProgressScreen.ChartRange
    let profile: UserProfile
    @Query private var entries: [DiaryEntry]

    init(range: ProgressScreen.ChartRange, profile: UserProfile) {
        self.range = range
        self.profile = profile
        let start = range.start()
        _entries = Query(filter: #Predicate<DiaryEntry> { $0.day >= start })
    }

    var body: some View {
        let days = DailySummary.byDay(entries).values.sorted { $0.day < $1.day }
        if days.isEmpty {
            LTComingSoon(systemImage: "chart.bar", title: "Nothing logged in this range", message: "Log some food and your daily calories show up here.")
        } else {
            Chart {
                ForEach(days) { d in
                    BarMark(x: .value("Day", d.day, unit: .day), y: .value("Calories", d.kcal))
                        .foregroundStyle(d.kcal > Double(profile.calorieGoal) * 1.1 ? Theme.fat : Theme.accent)
                }
                RuleMark(y: .value("Goal", Double(profile.calorieGoal)))
                    .foregroundStyle(Theme.textSecondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .annotation(position: .top, alignment: .leading) { Text("Goal").font(.caption2).foregroundStyle(Theme.textSecondary) }
            }
            .frame(height: 230)
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .accessibilityLabel("Calories chart for \(days.count) logged days")

            let average = days.map(\.kcal).reduce(0, +) / Double(days.count)
            StatPair(leftTitle: "Average a day", leftValue: "\(Format.calories(average)) cal",
                     rightTitle: "Days logged", rightValue: "\(days.count) of \(range.days)")
            let within = days.filter { abs($0.kcal - Double(profile.calorieGoal)) <= Double(profile.calorieGoal) * 0.1 }.count
            NoteCard(text: "\(within) of \(days.count) logged days were within 10% of your \(profile.calorieGoal.formatted())-calorie goal. Averages only count days with food logged.")
        }
    }
}

// MARK: - Macros

private struct MacrosProgress: View {
    let range: ProgressScreen.ChartRange
    let profile: UserProfile
    @Query private var entries: [DiaryEntry]

    init(range: ProgressScreen.ChartRange, profile: UserProfile) {
        self.range = range
        self.profile = profile
        let start = range.start()
        _entries = Query(filter: #Predicate<DiaryEntry> { $0.day >= start })
    }

    private struct MacroPoint: Identifiable {
        let day: Date
        let macro: String
        let grams: Double
        var id: String { "\(day.timeIntervalSince1970)-\(macro)" }
    }

    var body: some View {
        let days = DailySummary.byDay(entries).values.sorted { $0.day < $1.day }
        if days.isEmpty {
            LTComingSoon(systemImage: "chart.pie", title: "Nothing logged in this range", message: "Log some food to see your protein, carbs and fat.")
        } else {
            let points = days.flatMap { d in
                [MacroPoint(day: d.day, macro: "Protein", grams: d.protein),
                 MacroPoint(day: d.day, macro: "Carbs", grams: d.carbs),
                 MacroPoint(day: d.day, macro: "Fat", grams: d.fat)]
            }
            Chart(points) { p in
                BarMark(x: .value("Day", p.day, unit: .day), y: .value("Grams", p.grams))
                    .foregroundStyle(by: .value("Macro", p.macro))
            }
            .chartForegroundStyleScale(["Protein": Theme.protein, "Carbs": Theme.carbs, "Fat": Theme.fat])
            .frame(height: 230)
            .padding(12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))

            let n = Double(days.count)
            let avg = (protein: days.map(\.protein).reduce(0, +) / n, carbs: days.map(\.carbs).reduce(0, +) / n, fat: days.map(\.fat).reduce(0, +) / n)
            let goals = profile.macroGoals
            let shares = NutritionMath.roundedTo100({
                let s = NutritionMath.macroShares(protein: avg.protein, carbs: avg.carbs, fat: avg.fat)
                return [s.protein, s.carbs, s.fat]
            }())
            Text("Average per logged day").font(.headline).foregroundStyle(Theme.textPrimary).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 10) {
                MacroCard(name: "Protein", grams: avg.protein, goal: goals.protein, sharePercent: shares[0], color: Theme.protein)
                MacroCard(name: "Carbs", grams: avg.carbs, goal: goals.carbs, sharePercent: shares[1], color: Theme.carbs)
                MacroCard(name: "Fat", grams: avg.fat, goal: goals.fat, sharePercent: shares[2], color: Theme.fat)
            }
            Text("Your targets: protein \(Format.number(profile.proteinPercent))%, carbs \(Format.number(profile.carbsPercent))%, fat \(Format.number(profile.fatPercent))% of calories.")
                .font(.caption).foregroundStyle(Theme.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

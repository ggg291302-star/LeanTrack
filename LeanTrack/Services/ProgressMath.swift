import Foundation
import SwiftData

extension UserProfile {
    /// The calorie plan for the profile as it is now (current weight, goal, pace, activity).
    var recommendedPlan: EnergyMath.CaloriePlan {
        EnergyMath.plan(sex: sex, age: age(), weightKg: currentWeightKg, heightCm: heightCm, activity: activity, goal: goal,
                        paceLbPerWeek: paceLbPerWeek, goalWeightKg: goal == .maintain ? currentWeightKg : goalWeightKg,
                        pregnantOrBreastfeeding: pregnantOrBreastfeeding)
    }

    var bmi: Double { EnergyMath.bmi(weightKg: currentWeightKg, heightCm: heightCm) }

    /// Uses the recommended calories (unless the owner set their own) and keeps fiber in step.
    func applyRecommendedCalories() {
        let plan = recommendedPlan
        if plan.notes.contains(.noLossPlanUnder18) || plan.notes.contains(.noLossPlanPregnancy) { goal = .maintain }
        paceLbPerWeek = plan.paceLbPerWeek
        if !calorieGoalIsManual { calorieGoal = plan.calories }
        fiberGoalG = NutritionMath.fiberGoal(calories: calorieGoal)
        applyMacroPreset()
    }

    /// Re-applies the macro preset, so protein follows body weight and the calorie goal.
    /// A custom split is left alone.
    func applyMacroPreset() {
        if let p = macroPreset.percents(calories: Double(calorieGoal), weightKg: currentWeightKg) {
            setMacroPercents(protein: p.protein, carbs: p.carbs, fat: p.fat)
        }
    }

    func setMacroPercents(protein: Double, carbs: Double, fat: Double) {
        proteinPercent = protein
        carbsPercent = carbs
        fatPercent = fat
    }
}

/// Weigh-ins: saving them and keeping the profile's current weight in step.
enum WeightService {
    @discardableResult
    static func add(weightKg: Double, date: Date, note: String, profile: UserProfile?, in context: ModelContext) -> WeightEntry {
        let entry = WeightEntry(date: date, weightKg: weightKg, note: note.trimmingCharacters(in: .whitespacesAndNewlines))
        context.insert(entry)
        try? context.save()
        if let profile { syncCurrentWeight(profile: profile, in: context) }
        return entry
    }

    static func delete(_ entry: WeightEntry, profile: UserProfile?, in context: ModelContext) {
        context.delete(entry)
        try? context.save()
        if let profile { syncCurrentWeight(profile: profile, in: context) }
    }

    /// The profile's current weight is always the latest weigh-in.
    static func syncCurrentWeight(profile: UserProfile, in context: ModelContext) {
        var descriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        if let latest = try? context.fetch(descriptor).first {
            profile.currentWeightKg = latest.weightKg
            profile.applyMacroPreset()
            try? context.save()
        }
    }

    /// New calorie goal to offer after a weight change, when the goal is automatic and it moved by 10+ calories.
    static func suggestedCalorieUpdate(profile: UserProfile) -> Int? {
        guard !profile.calorieGoalIsManual else { return nil }
        let suggested = profile.recommendedPlan.calories
        return abs(suggested - profile.calorieGoal) >= 10 ? suggested : nil
    }
}

/// Weight trend math for Progress.
enum WeightTrend {
    struct Point: Hashable {
        var date: Date
        var kg: Double
    }

    /// Each weigh-in's average with the weigh-ins in the 7 days before it (smooths daily water swings).
    static func movingAverage(_ points: [Point], days: Int = 7) -> [Point] {
        let sorted = points.sorted { $0.date < $1.date }
        return sorted.map { p in
            let start = p.date.addingTimeInterval(-Double(days) * 86_400)
            let window = sorted.filter { $0.date > start && $0.date <= p.date }
            return Point(date: p.date, kg: window.map(\.kg).reduce(0, +) / Double(max(window.count, 1)))
        }
    }

    /// Change per week (kg) from a least-squares line through the last `days` days of weigh-ins.
    /// Nil with fewer than 3 weigh-ins spanning at least 7 days.
    static func kgPerWeek(_ points: [Point], days: Int = 28, now: Date = .now) -> Double? {
        let start = now.addingTimeInterval(-Double(days) * 86_400)
        let recent = points.filter { $0.date >= start && $0.date <= now }
        guard recent.count >= 3, let first = recent.map(\.date).min(), let last = recent.map(\.date).max(),
              last.timeIntervalSince(first) >= 7 * 86_400 else { return nil }
        let xs = recent.map { $0.date.timeIntervalSince(first) / 86_400 }
        let ys = recent.map(\.kg)
        let n = Double(xs.count)
        let mx = xs.reduce(0, +) / n, my = ys.reduce(0, +) / n
        let sxx = zip(xs, xs).map { ($0 - mx) * ($1 - mx) }.reduce(0, +)
        guard sxx > 0 else { return nil }
        let sxy = zip(xs, ys).map { ($0 - mx) * ($1 - my) }.reduce(0, +)
        return sxy / sxx * 7
    }

    /// When the goal is reached at this rate, if the rate is heading toward the goal.
    static func projectedDate(currentKg: Double, goalKg: Double, kgPerWeek: Double, from date: Date = .now) -> Date? {
        let remaining = goalKg - currentKg
        guard abs(remaining) >= 0.1, kgPerWeek != 0, remaining.sign == kgPerWeek.sign else { return nil }
        let weeks = remaining / kgPerWeek
        guard weeks < 520 else { return nil }
        return date.addingTimeInterval(weeks * 7 * 86_400)
    }
}

/// Totals for a set of diary entries, including every nutrient.
struct DayTotals {
    var kcal = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0
    var nutrients = Nutrients()
    /// For each nutrient key, how many entries had no value for it.
    var missing: [String: Int] = [:]
    var entryCount = 0

    init(_ entries: [DiaryEntry]) {
        entryCount = entries.count
        let all = entries.map(\.nutrients)
        nutrients = NutritionMath.sum(all)
        for info in NutrientInfo.all {
            let count = all.filter { $0[keyPath: info.keyPath] == nil }.count
            if count > 0 { missing[info.key] = count }
        }
        for e in entries { kcal += e.kcal; protein += e.protein; carbs += e.carbs; fat += e.fat }
    }
}

/// Per-day sums for charts.
struct DailySummary: Identifiable, Hashable {
    var day: Date
    var kcal = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0
    var id: Date { day }

    static func byDay(_ entries: [DiaryEntry]) -> [Date: DailySummary] {
        var result: [Date: DailySummary] = [:]
        for e in entries {
            var s = result[e.day] ?? DailySummary(day: e.day)
            s.kcal += e.kcal; s.protein += e.protein; s.carbs += e.carbs; s.fat += e.fat
            result[e.day] = s
        }
        return result
    }
}

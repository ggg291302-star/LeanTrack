import Foundation

enum Sex: String, Codable, CaseIterable, Identifiable, Sendable {
    case female, male
    var id: String { rawValue }
    var title: String { self == .female ? "Female" : "Male" }
}

/// Standard activity multipliers for TDEE (total daily energy expenditure).
enum ActivityLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case sedentary, light, moderate, veryActive, extraActive
    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .veryActive: 1.725
        case .extraActive: 1.9
        }
    }

    var title: String {
        switch self {
        case .sedentary: "Sedentary"
        case .light: "Lightly active"
        case .moderate: "Moderately active"
        case .veryActive: "Very active"
        case .extraActive: "Extra active"
        }
    }

    var explanation: String {
        switch self {
        case .sedentary: "Little or no exercise, desk job"
        case .light: "Light exercise 1–3 days a week"
        case .moderate: "Moderate exercise 3–5 days a week"
        case .veryActive: "Hard exercise 6–7 days a week"
        case .extraActive: "Very hard exercise or a physical job"
        }
    }
}

enum WeightGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case lose, maintain, gain
    var id: String { rawValue }
    var title: String {
        switch self {
        case .lose: "Lose weight"
        case .maintain: "Maintain weight"
        case .gain: "Gain weight"
        }
    }
}

/// Body and energy formulas. Every number here comes from a published source:
/// - BMR: Mifflin MD, St Jeor ST, et al. "A new predictive equation for resting energy
///   expenditure in healthy individuals." Am J Clin Nutr. 1990;51(2):241–247.
/// - TDEE = BMR × activity multiplier (1.2 / 1.375 / 1.55 / 1.725 / 1.9).
/// - About 3,500 kcal per pound of body weight (an estimate, shown as such in the app).
/// - BMI = kg / m² (CDC, WHO).
enum EnergyMath {
    static let kcalPerPound = 3500.0

    /// Mifflin-St Jeor resting energy: 10 × kg + 6.25 × cm − 5 × age + 5 (men) or − 161 (women).
    static func bmr(sex: Sex, weightKg: Double, heightCm: Double, age: Int) -> Double {
        10 * weightKg + 6.25 * heightCm - 5 * Double(age) + (sex == .male ? 5 : -161)
    }

    static func tdee(bmr: Double, activity: ActivityLevel) -> Double {
        bmr * activity.multiplier
    }

    /// BMI = kg ÷ m².
    static func bmi(weightKg: Double, heightCm: Double) -> Double {
        let m = heightCm / 100
        return weightKg / (m * m)
    }

    /// Lowest daily calories LeanTrack will suggest: 1,200 (women) or 1,500 (men).
    static func calorieFloor(sex: Sex) -> Double { sex == .male ? 1500 : 1200 }

    /// Fastest weight-loss pace LeanTrack will suggest: 2 lb a week or 1% of body weight a week, whichever is less.
    static func maxLossLbPerWeek(weightKg: Double) -> Double {
        min(2, UnitConversion.pounds(fromKilograms: weightKg) * 0.01)
    }

    struct CaloriePlan: Equatable, Sendable {
        var bmr: Double
        var tdee: Double
        /// Daily calories to aim for, rounded to the nearest 10.
        var calories: Int
        /// The pace actually used (may be lower than asked for).
        var paceLbPerWeek: Double
        var notes: [Note]
    }

    enum Note: Equatable, Sendable {
        case paceReduced(maxLbPerWeek: Double)
        case raisedToFloor(floor: Int)
        case noLossPlanUnder18
        case noLossPlanPregnancy
        case goalBMIUnderweight(bmi: Double)

        var text: String {
            switch self {
            case .paceReduced(let max):
                "Pace lowered to \(Format.number(max, decimals: 1)) lb per week, the safe maximum for your weight (2 lb or 1% of body weight a week)."
            case .raisedToFloor(let floor):
                "Raised to \(floor.formatted()) calories a day, the lowest amount LeanTrack suggests without a doctor's guidance."
            case .noLossPlanUnder18:
                "LeanTrack doesn't make weight-loss plans for people under 18. Please talk to a doctor about your goals. Your goal is set to maintain."
            case .noLossPlanPregnancy:
                "LeanTrack doesn't make weight-loss plans during pregnancy or breastfeeding. Please talk to your doctor. Your goal is set to maintain."
            case .goalBMIUnderweight(let bmi):
                "Your goal weight gives a BMI of \(Format.number(bmi, decimals: 1)), which is below the healthy range (18.5–24.9)."
            }
        }

        var isWarning: Bool {
            switch self {
            case .paceReduced, .raisedToFloor: false
            default: true
            }
        }
    }

    /// Suggested daily calories for a goal and pace, with the safety guardrails applied.
    static func plan(sex: Sex, age: Int, weightKg: Double, heightCm: Double, activity: ActivityLevel,
                     goal: WeightGoal, paceLbPerWeek: Double, goalWeightKg: Double, pregnantOrBreastfeeding: Bool) -> CaloriePlan {
        let restBurn = bmr(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age)
        let dailyBurn = tdee(bmr: restBurn, activity: activity)
        var notes: [Note] = []
        var goal = goal
        var pace = max(0, paceLbPerWeek)

        if goal == .lose && age < 18 { notes.append(.noLossPlanUnder18); goal = .maintain }
        if goal == .lose && pregnantOrBreastfeeding { notes.append(.noLossPlanPregnancy); goal = .maintain }

        let goalBMI = bmi(weightKg: goalWeightKg, heightCm: heightCm)
        if age >= 20 && goalBMI < 18.5 { notes.append(.goalBMIUnderweight(bmi: goalBMI)) }

        var target = dailyBurn
        switch goal {
        case .maintain:
            pace = 0
        case .lose:
            let maxPace = maxLossLbPerWeek(weightKg: weightKg)
            if pace > maxPace + 0.0001 { pace = maxPace; notes.append(.paceReduced(maxLbPerWeek: maxPace)) }
            target = dailyBurn - pace * kcalPerPound / 7
            let floor = calorieFloor(sex: sex)
            if target < floor { target = floor; notes.append(.raisedToFloor(floor: Int(floor))) }
        case .gain:
            pace = min(pace, 0.5)
            target = dailyBurn + pace * kcalPerPound / 7
        }
        return CaloriePlan(bmr: restBurn, tdee: dailyBurn, calories: Int((target / 10).rounded() * 10), paceLbPerWeek: pace, notes: notes)
    }

    /// Warnings for a calorie goal typed in by hand.
    static func manualGoalWarnings(calories: Int, sex: Sex) -> [String] {
        let floor = Int(calorieFloor(sex: sex))
        return calories < floor
            ? ["\(calories.formatted()) calories a day is below \(floor.formatted()), the lowest amount usually advised without a doctor's guidance."]
            : []
    }
}

/// Macro targets in grams.
struct MacroGrams: Equatable, Sendable {
    var protein: Double
    var carbs: Double
    var fat: Double

    /// 4 kcal per gram of protein and carbohydrate, 9 per gram of fat (Atwater general factors).
    static func fromPercents(calories: Double, protein: Double, carbs: Double, fat: Double) -> MacroGrams {
        MacroGrams(protein: calories * protein / 100 / 4, carbs: calories * carbs / 100 / 4, fat: calories * fat / 100 / 9)
    }
}

/// Macro splits. Balanced and High Protein stay inside the National Academies' Acceptable
/// Macronutrient Distribution Ranges (protein 10–35%, carbs 45–65%, fat 20–35% of calories;
/// High Protein uses the low end for carbs); Low Carb is intentionally below them.
enum MacroPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case balanced, highProtein, lowCarb, custom
    var id: String { rawValue }

    var title: String {
        switch self {
        case .balanced: "Balanced"
        case .highProtein: "High Protein"
        case .lowCarb: "Low Carb"
        case .custom: "Custom"
        }
    }

    /// Protein, carbs, fat in % of calories.
    var percents: (protein: Double, carbs: Double, fat: Double)? {
        switch self {
        case .balanced: (20, 50, 30)
        case .highProtein: (30, 45, 25)
        case .lowCarb: (30, 25, 45)
        case .custom: nil
        }
    }
}

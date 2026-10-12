import Foundation

enum WeightUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case lb, kg
    var id: String { rawValue }
}

enum HeightUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case feetInches, cm
    var id: String { rawValue }
    var title: String { self == .cm ? "cm" : "ft/in" }
}

enum FoodUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case ounces, grams
    var id: String { rawValue }
    var title: String { self == .grams ? "g" : "oz" }
}

enum VolumeUnit: String, Codable, CaseIterable, Identifiable, Sendable {
    case fluidOunces, milliliters
    var id: String { rawValue }
    var title: String { self == .milliliters ? "ml" : "fl oz" }
}

enum NutritionMath {
    /// Adds nutrient sets. Unlike `+`, a value missing in some items doesn't hide the
    /// whole total: totals add what's known (used for day totals of calories and macros).
    static func sum(_ items: [Nutrients]) -> Nutrients {
        var total = Nutrients()
        for path in Nutrients.allKeyPaths {
            let values = items.compactMap { $0[keyPath: path] }
            total[keyPath: path] = values.isEmpty ? nil : values.reduce(0, +)
        }
        return total
    }

    /// Each macro's share of the calories that come from macros, using 4/4/9 kcal per gram.
    /// The three always add up to 100% (or are all 0 when nothing was eaten).
    static func macroShares(protein: Double, carbs: Double, fat: Double) -> (protein: Double, carbs: Double, fat: Double) {
        let p = protein * 4, c = carbs * 4, f = fat * 9
        let total = p + c + f
        guard total > 0 else { return (0, 0, 0) }
        return (p / total * 100, c / total * 100, f / total * 100)
    }

    /// Rounds three percentages so they add up to exactly 100 (largest-remainder method).
    static func roundedTo100(_ values: [Double]) -> [Int] {
        guard values.reduce(0, +) > 0 else { return values.map { _ in 0 } }
        let floors = values.map { Int($0.rounded(.down)) }
        var result = floors
        let missing = 100 - floors.reduce(0, +)
        let order = values.indices.sorted { (values[$0] - Double(floors[$0])) > (values[$1] - Double(floors[$1])) }
        for i in 0..<max(0, min(missing, order.count)) { result[order[i]] += 1 }
        return result
    }

    /// Calories left today: goal − food (+ exercise, only when that setting is on).
    static func remaining(goal: Int, eaten: Double, exercise: Double = 0, addExercise: Bool = false) -> Double {
        Double(goal) - eaten + (addExercise ? exercise : 0)
    }

    /// Daily fiber target: 14 g per 1,000 calories (Dietary Guidelines for Americans 2020–2025).
    static func fiberGoal(calories: Int) -> Double {
        (Double(calories) / 1000 * 14).rounded()
    }

    /// Daily water target from the National Academies' Adequate Intake for total beverages
    /// (about 9 cups / 2.2 L for women, 13 cups / 3.0 L for men).
    static func defaultWaterGoalMl(sex: Sex) -> Double { sex == .male ? 3000 : 2200 }
}

/// Number and amount formatting used everywhere.
enum Format {
    static func number(_ value: Double, decimals: Int = 0) -> String {
        value.formatted(.number.precision(.fractionLength(0...decimals)))
    }

    static func calories(_ value: Double?) -> String {
        guard let value else { return "—" }
        return Int(value.rounded()).formatted()
    }

    /// Grams for macro display: 1 decimal under 10 g, whole grams above.
    static func grams(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value < 10 && value > 0 ? number(value, decimals: 1) : number(value)
    }

    /// "1½ cup", "3 oz", "150 g".
    static func amount(_ value: Double, unit: String) -> String {
        "\(quantity(value)) \(unit)"
    }

    static func quantity(_ value: Double) -> String {
        let whole = value.rounded(.down)
        let fraction = value - whole
        let symbols: [(Double, String)] = [(0.25, "¼"), (1.0 / 3, "⅓"), (0.5, "½"), (2.0 / 3, "⅔"), (0.75, "¾")]
        if fraction > 0.001, let match = symbols.first(where: { abs($0.0 - fraction) < 0.01 }) {
            return whole > 0 ? "\(Int(whole))\(match.1)" : match.1
        }
        return number(value, decimals: 2)
    }

    /// "165 cal • 31g P • 0g C • 3.6g F"
    static func macroLine(_ n: Nutrients) -> String {
        "\(calories(n.kcal)) cal • \(grams(n.protein))g P • \(grams(n.carbs))g C • \(grams(n.fat))g F"
    }

    static func weight(kg: Double, unit: WeightUnit, decimals: Int = 1) -> String {
        unit == .kg ? "\(number(kg, decimals: decimals)) kg" : "\(number(UnitConversion.pounds(fromKilograms: kg), decimals: decimals)) lb"
    }

    static func height(cm: Double, unit: HeightUnit) -> String {
        if unit == .cm { return "\(number(cm)) cm" }
        let fi = UnitConversion.feetAndInches(fromCentimeters: cm)
        return "\(fi.feet) ft \(number(fi.inches)) in"
    }

    static func volume(ml: Double, unit: VolumeUnit) -> String {
        unit == .milliliters ? "\(number(ml)) ml" : "\(number(UnitConversion.fluidOunces(fromMilliliters: ml))) fl oz"
    }

    static func dayTitle(_ day: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        if calendar.isDateInTomorrow(day) { return "Tomorrow" }
        return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

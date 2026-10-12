import Foundation

/// Display info for every nutrient LeanTrack tracks.
///
/// Daily Values are the FDA's for adults and children 4 years and older
/// (21 CFR 101.9(c)(8)(iv) and (c)(9), the 2016 Nutrition Facts label rule).
struct NutrientInfo: Identifiable, Sendable {
    /// Same as the foods.sqlite column name ("sat_fat").
    let key: String
    let name: String
    /// "kcal", "g", "mg" or "µg".
    let unit: String
    let keyPath: WritableKeyPath<Nutrients, Double?>
    let dailyValue: Double?
    /// Shown indented under the line above it (like "Saturated fat" under "Fat").
    var indented = false
    /// USDA FoodData Central nutrient IDs, best first (same as scripts/build-food-db.mjs).
    let usdaIDs: [Int]
    /// Open Food Facts `nutriments` name (without "_100g"). OFF stores these in grams.
    let offName: String?

    var id: String { key }

    func format(_ value: Double?) -> String {
        guard let value else { return "—" }
        switch unit {
        case "kcal": return Format.calories(value)
        case "g": return Format.grams(value) + " g"
        default:
            let decimals = value < 10 ? (value < 1 ? 2 : 1) : 0
            return Format.number(value, decimals: decimals) + " \(unit)"
        }
    }

    /// Percent of the Daily Value, when there is one.
    func percentDV(_ value: Double?) -> Int? {
        guard let value, let dailyValue, dailyValue > 0 else { return nil }
        return Int((value / dailyValue * 100).rounded())
    }

    static let all: [NutrientInfo] = [
        NutrientInfo(key: "kcal", name: "Calories", unit: "kcal", keyPath: \.kcal, dailyValue: nil, usdaIDs: [1008, 2048, 2047], offName: "energy-kcal"),
        NutrientInfo(key: "fat", name: "Fat", unit: "g", keyPath: \.fat, dailyValue: 78, usdaIDs: [1004], offName: "fat"),
        NutrientInfo(key: "sat_fat", name: "Saturated fat", unit: "g", keyPath: \.satFat, dailyValue: 20, indented: true, usdaIDs: [1258], offName: "saturated-fat"),
        NutrientInfo(key: "trans_fat", name: "Trans fat", unit: "g", keyPath: \.transFat, dailyValue: nil, indented: true, usdaIDs: [1257], offName: "trans-fat"),
        NutrientInfo(key: "mono_fat", name: "Monounsaturated fat", unit: "g", keyPath: \.monoFat, dailyValue: nil, indented: true, usdaIDs: [1292], offName: "monounsaturated-fat"),
        NutrientInfo(key: "poly_fat", name: "Polyunsaturated fat", unit: "g", keyPath: \.polyFat, dailyValue: nil, indented: true, usdaIDs: [1293], offName: "polyunsaturated-fat"),
        NutrientInfo(key: "cholesterol", name: "Cholesterol", unit: "mg", keyPath: \.cholesterol, dailyValue: 300, usdaIDs: [1253], offName: "cholesterol"),
        NutrientInfo(key: "sodium", name: "Sodium", unit: "mg", keyPath: \.sodium, dailyValue: 2300, usdaIDs: [1093], offName: "sodium"),
        NutrientInfo(key: "carbs", name: "Carbohydrates", unit: "g", keyPath: \.carbs, dailyValue: 275, usdaIDs: [1005, 1050], offName: "carbohydrates"),
        NutrientInfo(key: "fiber", name: "Fiber", unit: "g", keyPath: \.fiber, dailyValue: 28, indented: true, usdaIDs: [1079], offName: "fiber"),
        NutrientInfo(key: "sugar", name: "Sugars", unit: "g", keyPath: \.sugar, dailyValue: nil, indented: true, usdaIDs: [2000, 1063], offName: "sugars"),
        NutrientInfo(key: "protein", name: "Protein", unit: "g", keyPath: \.protein, dailyValue: 50, usdaIDs: [1003], offName: "proteins"),
        NutrientInfo(key: "vit_d", name: "Vitamin D", unit: "µg", keyPath: \.vitaminD, dailyValue: 20, usdaIDs: [1114], offName: "vitamin-d"),
        NutrientInfo(key: "calcium", name: "Calcium", unit: "mg", keyPath: \.calcium, dailyValue: 1300, usdaIDs: [1087], offName: "calcium"),
        NutrientInfo(key: "iron", name: "Iron", unit: "mg", keyPath: \.iron, dailyValue: 18, usdaIDs: [1089], offName: "iron"),
        NutrientInfo(key: "potassium", name: "Potassium", unit: "mg", keyPath: \.potassium, dailyValue: 4700, usdaIDs: [1092], offName: "potassium"),
        NutrientInfo(key: "magnesium", name: "Magnesium", unit: "mg", keyPath: \.magnesium, dailyValue: 420, usdaIDs: [1090], offName: "magnesium"),
        NutrientInfo(key: "phosphorus", name: "Phosphorus", unit: "mg", keyPath: \.phosphorus, dailyValue: 1250, usdaIDs: [1091], offName: "phosphorus"),
        NutrientInfo(key: "zinc", name: "Zinc", unit: "mg", keyPath: \.zinc, dailyValue: 11, usdaIDs: [1095], offName: "zinc"),
        // Vitamin A from Open Food Facts is label "retinol equivalents", not RAE, so it isn't mapped.
        NutrientInfo(key: "vit_a", name: "Vitamin A", unit: "µg", keyPath: \.vitaminA, dailyValue: 900, usdaIDs: [1106], offName: nil),
        NutrientInfo(key: "vit_c", name: "Vitamin C", unit: "mg", keyPath: \.vitaminC, dailyValue: 90, usdaIDs: [1162], offName: "vitamin-c"),
        NutrientInfo(key: "vit_e", name: "Vitamin E", unit: "mg", keyPath: \.vitaminE, dailyValue: 15, usdaIDs: [1109], offName: "vitamin-e"),
        NutrientInfo(key: "vit_k", name: "Vitamin K", unit: "µg", keyPath: \.vitaminK, dailyValue: 120, usdaIDs: [1185], offName: "vitamin-k"),
        NutrientInfo(key: "thiamin", name: "Thiamin (B1)", unit: "mg", keyPath: \.thiamin, dailyValue: 1.2, usdaIDs: [1165], offName: "vitamin-b1"),
        NutrientInfo(key: "riboflavin", name: "Riboflavin (B2)", unit: "mg", keyPath: \.riboflavin, dailyValue: 1.3, usdaIDs: [1166], offName: "vitamin-b2"),
        NutrientInfo(key: "niacin", name: "Niacin (B3)", unit: "mg", keyPath: \.niacin, dailyValue: 16, usdaIDs: [1167], offName: "vitamin-pp"),
        NutrientInfo(key: "vit_b6", name: "Vitamin B6", unit: "mg", keyPath: \.vitaminB6, dailyValue: 1.7, usdaIDs: [1175], offName: "vitamin-b6"),
        // Folate in µg DFE. Open Food Facts doesn't say whether label folate is DFE, so it isn't mapped.
        NutrientInfo(key: "folate", name: "Folate", unit: "µg", keyPath: \.folate, dailyValue: 400, usdaIDs: [1190], offName: nil),
        NutrientInfo(key: "vit_b12", name: "Vitamin B12", unit: "µg", keyPath: \.vitaminB12, dailyValue: 2.4, usdaIDs: [1178], offName: "vitamin-b12"),
        NutrientInfo(key: "caffeine", name: "Caffeine", unit: "mg", keyPath: \.caffeine, dailyValue: nil, usdaIDs: [1057], offName: "caffeine"),
        // Open Food Facts lists alcohol as % by volume, not grams, so it isn't mapped.
        NutrientInfo(key: "alcohol", name: "Alcohol", unit: "g", keyPath: \.alcohol, dailyValue: nil, usdaIDs: [1018], offName: nil),
    ]

    static func info(for key: String) -> NutrientInfo? { all.first { $0.key == key } }

    /// Groups for the Nutrition Facts list.
    static let sections: [(title: String, keys: [String])] = [
        ("Nutrition Facts", ["kcal", "fat", "sat_fat", "trans_fat", "mono_fat", "poly_fat", "cholesterol", "sodium", "carbs", "fiber", "sugar", "protein"]),
        ("Vitamins & Minerals", ["vit_d", "calcium", "iron", "potassium", "magnesium", "phosphorus", "zinc", "vit_a", "vit_c", "vit_e", "vit_k",
                                 "thiamin", "riboflavin", "niacin", "vit_b6", "folate", "vit_b12"]),
        ("Other", ["caffeine", "alcohol"]),
    ]

    /// Nutrients that can be added as an extra goal in Goals → "+ Add Goal".
    static let goalCandidates = ["sodium", "sugar", "sat_fat", "cholesterol", "potassium", "calcium", "iron", "vit_d", "vit_c", "caffeine"]

    /// Converts an amount between mass units ("G", "MG", "UG"/"µg") and energy ("KCAL", "kJ").
    /// Returns nil for units that can't be converted (like IU).
    static func convert(_ value: Double, from unit: String, to target: String) -> Double? {
        func scale(_ u: String) -> (kind: String, factor: Double)? {
            switch u.lowercased() {
            case "g", "grm": ("mass", 1)
            case "mg": ("mass", 1e-3)
            case "ug", "µg", "mcg", "μg": ("mass", 1e-6)
            case "kcal": ("energy", 1)
            case "kj": ("energy", 1 / 4.184)
            default: nil
            }
        }
        guard let from = scale(unit), let to = scale(target), from.kind == to.kind else { return nil }
        return value * from.factor / to.factor
    }
}

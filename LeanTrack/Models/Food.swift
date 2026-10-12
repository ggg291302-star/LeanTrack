import Foundation

/// Nutrients per 100 g, exactly as USDA reports them. `nil` means USDA has no value
/// (the app shows "—" instead of guessing).
struct Nutrients: Codable, Hashable, Sendable {
    var kcal: Double?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var fiber: Double?
    var sugar: Double?
    var satFat: Double?
    var transFat: Double?
    var monoFat: Double?
    var polyFat: Double?
    var cholesterol: Double?   // mg
    var sodium: Double?        // mg
    var potassium: Double?     // mg
    var calcium: Double?       // mg
    var iron: Double?          // mg
    var magnesium: Double?     // mg
    var phosphorus: Double?    // mg
    var zinc: Double?          // mg
    var vitaminA: Double?      // µg RAE
    var vitaminC: Double?      // mg
    var vitaminD: Double?      // µg
    var vitaminE: Double?      // mg
    var vitaminK: Double?      // µg
    var thiamin: Double?       // mg
    var riboflavin: Double?    // mg
    var niacin: Double?        // mg
    var vitaminB6: Double?     // mg
    var folate: Double?        // µg DFE
    var vitaminB12: Double?    // µg
    var caffeine: Double?      // mg
    var alcohol: Double?       // g

    /// Same names as the foods.sqlite columns and recipes.json.
    enum CodingKeys: String, CodingKey {
        case kcal, protein, carbs, fat, fiber, sugar
        case satFat = "sat_fat", transFat = "trans_fat", monoFat = "mono_fat", polyFat = "poly_fat"
        case cholesterol, sodium, potassium, calcium, iron, magnesium, phosphorus, zinc
        case vitaminA = "vit_a", vitaminC = "vit_c", vitaminD = "vit_d", vitaminE = "vit_e", vitaminK = "vit_k"
        case thiamin, riboflavin, niacin, vitaminB6 = "vit_b6", folate, vitaminB12 = "vit_b12"
        case caffeine, alcohol
    }

    /// Column names in foods.sqlite, in the same order as `allKeyPaths`.
    static let columns = [
        "kcal", "protein", "carbs", "fat", "fiber", "sugar", "sat_fat", "trans_fat", "mono_fat", "poly_fat",
        "cholesterol", "sodium", "potassium", "calcium", "iron", "magnesium", "phosphorus", "zinc",
        "vit_a", "vit_c", "vit_d", "vit_e", "vit_k", "thiamin", "riboflavin", "niacin", "vit_b6", "folate", "vit_b12",
        "caffeine", "alcohol",
    ]

    static let allKeyPaths: [WritableKeyPath<Nutrients, Double?>] = [
        \.kcal, \.protein, \.carbs, \.fat, \.fiber, \.sugar, \.satFat, \.transFat, \.monoFat, \.polyFat,
        \.cholesterol, \.sodium, \.potassium, \.calcium, \.iron, \.magnesium, \.phosphorus, \.zinc,
        \.vitaminA, \.vitaminC, \.vitaminD, \.vitaminE, \.vitaminK, \.thiamin, \.riboflavin, \.niacin, \.vitaminB6, \.folate, \.vitaminB12,
        \.caffeine, \.alcohol,
    ]

    /// These nutrients scaled from 100 g to `grams`. Missing values stay missing.
    func scaled(toGrams grams: Double) -> Nutrients {
        scaled(by: grams / 100)
    }

    /// Every value multiplied by `factor` (e.g. 2 servings → 2).
    func scaled(by factor: Double) -> Nutrients {
        var result = Nutrients()
        for path in Nutrients.allKeyPaths {
            result[keyPath: path] = self[keyPath: path].map { $0 * factor }
        }
        return result
    }

    /// Adds two nutrient sets. If either side is missing a value, the total is missing too,
    /// so a total is never shown as complete when part of it is unknown.
    static func + (lhs: Nutrients, rhs: Nutrients) -> Nutrients {
        var result = Nutrients()
        for path in Nutrients.allKeyPaths {
            if let a = lhs[keyPath: path], let b = rhs[keyPath: path] {
                result[keyPath: path] = a + b
            }
        }
        return result
    }

    static let zero: Nutrients = {
        var n = Nutrients()
        for path in Nutrients.allKeyPaths { n[keyPath: path] = 0 }
        return n
    }()
}

/// A real USDA household measure, for example "1 cup, chopped" = 160 g.
struct Portion: Codable, Hashable, Sendable {
    var amount: Double
    var unit: String
    var grams: Double

    var gramsPerUnit: Double { grams / amount }
}

/// Which USDA dataset a food came from.
enum FoodSource: String, Codable, Sendable {
    case foundation = "F"
    case srLegacy = "S"
    case fndds = "N"

    var displayName: String {
        switch self {
        case .foundation: "USDA Foundation Foods"
        case .srLegacy: "USDA SR Legacy"
        case .fndds: "USDA FNDDS (Survey Foods)"
        }
    }
}

/// A food from the built-in USDA database.
struct Food: Identifiable, Hashable, Sendable {
    let id: Int              // USDA FoodData Central ID (FDC ID)
    let name: String         // short, readable name for lists
    let usdaName: String     // original USDA description
    let source: FoodSource
    let category: String?
    let group: String        // icon group, e.g. "fruit", "poultry"
    let filledFromID: Int?   // SR Legacy FDC ID used for nutrients Foundation hasn't measured
    let nutrients: Nutrients // per 100 g
    let portions: [Portion]

    var fdcURL: URL { URL(string: "https://fdc.nal.usda.gov/food-details/\(id)/nutrients")! }
}

/// A row in search results and lists (no portions or full nutrients, so it stays light).
struct FoodSummary: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let usdaName: String
    let group: String
    let kcalPer100g: Double?
}

/// An entry in the hand-picked Common list, with its default USDA portion.
struct CommonFood: Identifiable, Hashable, Sendable {
    let rank: Int
    let foodID: Int
    let name: String
    let portion: Portion

    var id: Int { rank }
}

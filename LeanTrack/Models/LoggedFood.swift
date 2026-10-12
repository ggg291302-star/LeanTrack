import Foundation

/// Where a food in the diary came from.
enum FoodKind: String, Codable, Sendable {
    case usda          // built-in USDA database (refID = FDC ID)
    case usdaBranded   // USDA FoodData Central online, branded (refID = FDC ID)
    case openFoodFacts // Open Food Facts product (refID = barcode)
    case custom        // the owner's custom food (refID = UUID)
    case recipe        // bundled recipe (refID = recipe id)
    case userRecipe    // the owner's own recipe (refID = UUID)
    case savedMeal     // the owner's saved meal (refID = UUID)

    var sourceName: String {
        switch self {
        case .usda: "USDA FoodData Central"
        case .usdaBranded: "USDA Branded Foods"
        case .openFoodFacts: "Open Food Facts"
        case .custom: "Custom food"
        case .recipe: "Recipe"
        case .userRecipe: "My recipe"
        case .savedMeal: "Saved meal"
        }
    }
}

/// A unit the owner can pick in the serving picker.
struct ServingUnit: Codable, Hashable, Sendable, Identifiable {
    /// Shown in the picker: "g", "oz", "cup, chopped", "serving".
    var name: String
    /// Grams in one of this unit, when known. A recipe "serving" may have no gram weight.
    var grams: Double?

    var id: String { name }

    static let gram = ServingUnit(name: "g", grams: 1)
    static let ounce = ServingUnit(name: "oz", grams: UnitConversion.gramsPerOunce)
}

/// Everything needed to log a food and change its amount later, even offline:
/// a copy of its nutrients and units, taken when it was logged.
struct LoggedFood: Codable, Hashable, Sendable {
    var name: String
    var detail: String?            // brand, or USDA description
    var kind: FoodKind
    var refID: String?
    var group: String              // icon group ("fruit", "poultry", ...)
    /// Nutrients for 100 g, when the food has a gram weight.
    var per100g: Nutrients?
    /// Nutrients for 1 "serving" unit (recipes, saved meals, custom foods without grams).
    var perServing: Nutrients?
    /// Units to pick from, in order. The first is the default.
    var units: [ServingUnit]
    var imageURL: String?
    /// UPC/EAN, for packaged foods.
    var barcode: String? = nil

    /// Nutrients for an amount of a unit. Nil when the unit can't be converted.
    func nutrients(amount: Double, unit: ServingUnit) -> Nutrients? {
        if unit.name == "serving", let perServing {
            return perServing.scaled(by: amount)
        }
        if let grams = unit.grams, let per100g {
            return per100g.scaled(toGrams: amount * grams)
        }
        if let grams = unit.grams, let perServing, let servingGrams = units.first(where: { $0.name == "serving" })?.grams, servingGrams > 0 {
            return perServing.scaled(by: amount * grams / servingGrams)
        }
        return nil
    }

    func grams(amount: Double, unit: ServingUnit) -> Double? {
        unit.grams.map { $0 * amount }
    }

    /// Picker units for a USDA food: its real USDA portions, then grams and ounces.
    static func units(for portions: [Portion]) -> [ServingUnit] {
        var units: [ServingUnit] = []
        for p in portions where p.grams > 0 && p.amount > 0 {
            let unit = ServingUnit(name: p.unit, grams: p.gramsPerUnit)
            if !units.contains(where: { $0.name == unit.name }) { units.append(unit) }
        }
        return units + [.gram, .ounce]
    }

    static func fromUSDA(_ food: Food) -> LoggedFood {
        LoggedFood(name: food.name, detail: food.usdaName, kind: .usda, refID: String(food.id), group: food.group,
                   per100g: food.nutrients, perServing: nil, units: units(for: food.portions), imageURL: nil)
    }

    static func fromRecipe(_ recipe: Recipe) -> LoggedFood {
        LoggedFood(name: recipe.title, detail: recipe.source, kind: .recipe, refID: recipe.id, group: "meal",
                   per100g: nil, perServing: recipe.nutritionPerServing, units: [ServingUnit(name: "serving", grams: nil)], imageURL: nil)
    }
}

extension LoggedFood {
    /// Nutrients for 1 of the first unit (or 100 g), for list rows.
    var defaultPortion: FoodPortion { FoodPortion.defaultFor(self) }
}

/// An amount of a logged food. Used for diary entries, saved-meal items and recipe ingredients.
struct FoodPortion: Codable, Hashable, Sendable, Identifiable {
    var id = UUID()
    var food: LoggedFood
    var amount: Double
    var unit: ServingUnit

    var nutrients: Nutrients { food.nutrients(amount: amount, unit: unit) ?? Nutrients() }
    var grams: Double? { food.grams(amount: amount, unit: unit) }
    var amountText: String { Format.amount(amount, unit: unit.name) }

    /// 1 of the food's first unit, or 100 g when grams are the only unit.
    static func defaultFor(_ food: LoggedFood) -> FoodPortion {
        guard let first = food.units.first else { return FoodPortion(food: food, amount: 100, unit: .gram) }
        return FoodPortion(food: food, amount: first.name == "g" || first.name == "ml" ? 100 : 1, unit: first)
    }

    /// The everyday amount of a USDA food: its Common-list portion (with the friendlier
    /// Common name), else its first USDA household measure, else 100 g.
    static func defaultFor(_ food: Food, database: FoodDatabase? = FoodDatabase.shared) -> FoodPortion {
        var logged = LoggedFood.fromUSDA(food)
        if let common = database?.commonEntry(foodID: food.id), common.portion.amount > 0, common.portion.grams > 0 {
            logged.name = common.name
            let unit = ServingUnit(name: common.portion.unit, grams: common.portion.grams / common.portion.amount)
            if let existing = logged.units.first(where: { $0.name == unit.name }) {
                logged.units.removeAll { $0.name == unit.name }
                logged.units.insert(existing, at: 0)
            } else {
                logged.units.insert(unit, at: 0)
            }
            return FoodPortion(food: logged, amount: common.portion.amount, unit: logged.units[0])
        }
        return defaultFor(logged)
    }
}

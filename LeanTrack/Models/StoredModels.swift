import Foundation
import SwiftData

// Everything the owner saves lives here (SwiftData, on the phone only).
// Rules that keep reinstalling safe: never rename or remove a stored property;
// new properties always get a default value.

/// The owner's profile and goals. There is only ever one.
@Model
final class UserProfile {
    var name: String = ""
    var sexRaw: String = Sex.female.rawValue
    var birthDate: Date = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    var heightCm: Double = 170
    var currentWeightKg: Double = 70
    var startWeightKg: Double = 70
    var goalWeightKg: Double = 70
    var activityRaw: String = ActivityLevel.light.rawValue
    var goalRaw: String = WeightGoal.maintain.rawValue
    var paceLbPerWeek: Double = 0
    var pregnantOrBreastfeeding: Bool = false
    var calorieGoal: Int = 2000
    var calorieGoalIsManual: Bool = false
    var proteinPercent: Double = 20
    var carbsPercent: Double = 50
    var fatPercent: Double = 30
    var macroPresetRaw: String = MacroPreset.balanced.rawValue
    var fiberGoalG: Double = 28
    var waterGoalMl: Double = 2_200
    var weightUnitRaw: String = WeightUnit.lb.rawValue
    var heightUnitRaw: String = HeightUnit.feetInches.rawValue
    var foodUnitRaw: String = FoodUnit.ounces.rawValue
    var volumeUnitRaw: String = VolumeUnit.fluidOunces.rawValue
    var exerciseAddsBack: Bool = false
    var setupComplete: Bool = false
    var createdAt: Date = Date.now
    /// Waist in cm for the waist-to-height ratio (0 = not entered).
    var waistCm: Double = 0
    /// Extra daily nutrient goals from "+ Add Goal", JSON of [nutrient key: amount].
    var extraGoalsData: Data = Data()

    init() {}

    var sex: Sex { get { Sex(rawValue: sexRaw) ?? .female } set { sexRaw = newValue.rawValue } }
    var activity: ActivityLevel { get { ActivityLevel(rawValue: activityRaw) ?? .light } set { activityRaw = newValue.rawValue } }
    var goal: WeightGoal { get { WeightGoal(rawValue: goalRaw) ?? .maintain } set { goalRaw = newValue.rawValue } }
    var macroPreset: MacroPreset { get { MacroPreset(rawValue: macroPresetRaw) ?? .balanced } set { macroPresetRaw = newValue.rawValue } }
    var weightUnit: WeightUnit { get { WeightUnit(rawValue: weightUnitRaw) ?? .lb } set { weightUnitRaw = newValue.rawValue } }
    var heightUnit: HeightUnit { get { HeightUnit(rawValue: heightUnitRaw) ?? .feetInches } set { heightUnitRaw = newValue.rawValue } }
    var foodUnit: FoodUnit { get { FoodUnit(rawValue: foodUnitRaw) ?? .ounces } set { foodUnitRaw = newValue.rawValue } }
    var volumeUnit: VolumeUnit { get { VolumeUnit(rawValue: volumeUnitRaw) ?? .fluidOunces } set { volumeUnitRaw = newValue.rawValue } }

    func age(on date: Date = .now) -> Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: date).year ?? 0
    }

    /// Extra nutrient goals, e.g. ["sodium": 2300]. Keys are `NutrientInfo.key`.
    var extraGoals: [String: Double] {
        get { (try? JSONDecoder().decode([String: Double].self, from: extraGoalsData)) ?? [:] }
        set { extraGoalsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    /// Daily macro targets in grams, from the calorie goal and the percentages.
    var macroGoals: MacroGrams {
        MacroGrams.fromPercents(calories: Double(calorieGoal), protein: proteinPercent, carbs: carbsPercent, fat: fatPercent)
    }
}

/// One food logged in the diary.
@Model
final class DiaryEntry {
    @Attribute(.unique) var id: UUID = UUID()
    /// Start of the local day this entry belongs to.
    var day: Date = Calendar.current.startOfDay(for: .now)
    var createdAt: Date = Date.now
    var mealRaw: String = MealSlot.snacks.rawValue
    var name: String = ""
    var amount: Double = 1
    var unitName: String = "g"
    // Totals for the logged amount, kept for quick sums.
    var kcal: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    /// JSON of `FoodPortion` (food snapshot + amount + unit).
    var portionData: Data = Data()

    init(portion: FoodPortion, meal: MealSlot, day: Date) {
        self.id = UUID()
        self.day = Calendar.current.startOfDay(for: day)
        self.createdAt = .now
        self.mealRaw = meal.rawValue
        self.portionData = Data()
        self.portion = portion
    }

    var meal: MealSlot { get { MealSlot(rawValue: mealRaw) ?? .snacks } set { mealRaw = newValue.rawValue } }

    /// Setting this updates the name, amount and cached totals too.
    var portion: FoodPortion {
        get { (try? JSONDecoder().decode(FoodPortion.self, from: portionData)) ?? FoodPortion(food: LoggedFood(name: name, detail: nil, kind: .custom, refID: nil, group: "other", per100g: nil, perServing: Nutrients(kcal: kcal, protein: protein, carbs: carbs, fat: fat), units: [ServingUnit(name: "serving", grams: nil)], imageURL: nil), amount: 1, unit: ServingUnit(name: "serving", grams: nil)) }
        set {
            portionData = (try? JSONEncoder().encode(newValue)) ?? Data()
            name = newValue.food.name
            amount = newValue.amount
            unitName = newValue.unit.name
            let n = newValue.nutrients
            kcal = n.kcal ?? 0
            protein = n.protein ?? 0
            carbs = n.carbs ?? 0
            fat = n.fat ?? 0
        }
    }

    var nutrients: Nutrients { portion.nutrients }
}

/// Water the owner drank.
@Model
final class WaterEntry {
    @Attribute(.unique) var id: UUID = UUID()
    var day: Date = Calendar.current.startOfDay(for: .now)
    var createdAt: Date = Date.now
    var milliliters: Double = 0

    init(milliliters: Double, day: Date) {
        self.id = UUID()
        self.day = Calendar.current.startOfDay(for: day)
        self.createdAt = .now
        self.milliliters = milliliters
    }
}

/// A food the owner typed in, with nutrients per serving (from the package label).
@Model
final class CustomFood {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var brand: String = ""
    var barcode: String = ""
    var servingName: String = "1 serving"
    /// Grams in one serving, if the label says (lets the owner log in g/oz too).
    var servingGrams: Double = 0
    var nutrientsData: Data = Data()
    var createdAt: Date = Date.now

    init() {}

    var nutrientsPerServing: Nutrients {
        get { (try? JSONDecoder().decode(Nutrients.self, from: nutrientsData)) ?? Nutrients() }
        set { nutrientsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var loggedFood: LoggedFood {
        var units = [ServingUnit(name: "serving", grams: servingGrams > 0 ? servingGrams : nil)]
        if servingGrams > 0 { units += [.gram, .ounce] }
        return LoggedFood(name: name, detail: [brand, servingName].filter { !$0.isEmpty }.joined(separator: " · "), kind: .custom,
                          refID: id.uuidString, group: "other", per100g: nil, perServing: nutrientsPerServing, units: units, imageURL: nil)
    }
}

/// Several foods saved together, like "Chicken, Rice & Broccoli".
@Model
final class SavedMeal {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var itemsData: Data = Data()
    var createdAt: Date = Date.now

    init(name: String, items: [FoodPortion]) {
        self.id = UUID()
        self.name = name
        self.createdAt = .now
        self.itemsData = Data()
        self.items = items
    }

    var items: [FoodPortion] {
        get { (try? JSONDecoder().decode([FoodPortion].self, from: itemsData)) ?? [] }
        set { itemsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var totalNutrients: Nutrients { NutritionMath.sum(items.map(\.nutrients)) }

    var loggedFood: LoggedFood {
        LoggedFood(name: name, detail: "\(items.count) items", kind: .savedMeal, refID: id.uuidString, group: "meal",
                   per100g: nil, perServing: totalNutrients, units: [ServingUnit(name: "serving", grams: nil)], imageURL: nil)
    }
}

/// A recipe the owner made from foods in the database.
@Model
final class UserRecipe {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String = ""
    var servings: Int = 4
    var itemsData: Data = Data()
    var steps: String = ""
    var createdAt: Date = Date.now

    init(title: String, servings: Int, items: [FoodPortion], steps: String) {
        self.id = UUID()
        self.title = title
        self.servings = servings
        self.steps = steps
        self.createdAt = .now
        self.itemsData = Data()
        self.items = items
    }

    var items: [FoodPortion] {
        get { (try? JSONDecoder().decode([FoodPortion].self, from: itemsData)) ?? [] }
        set { itemsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var nutritionPerServing: Nutrients {
        NutritionMath.sum(items.map(\.nutrients)).scaled(by: 1 / Double(max(servings, 1)))
    }

    var loggedFood: LoggedFood {
        LoggedFood(name: title, detail: "My recipe · \(servings) servings", kind: .userRecipe, refID: id.uuidString, group: "meal",
                   per100g: nil, perServing: nutritionPerServing, units: [ServingUnit(name: "serving", grams: nil)], imageURL: nil)
    }
}

/// A favorite food, recipe or meal. `key` is "<kind>:<refID>".
@Model
final class FavoriteItem {
    @Attribute(.unique) var key: String = ""
    var foodData: Data = Data()
    var createdAt: Date = Date.now

    init(food: LoggedFood) {
        self.key = FavoriteItem.key(for: food)
        self.createdAt = .now
        self.foodData = (try? JSONEncoder().encode(food)) ?? Data()
    }

    var food: LoggedFood? { try? JSONDecoder().decode(LoggedFood.self, from: foodData) }

    static func key(for food: LoggedFood) -> String { "\(food.kind.rawValue):\(food.refID ?? food.name)" }
}

/// A weigh-in.
@Model
final class WeightEntry {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date = Date.now
    var weightKg: Double = 0
    var note: String = ""
    var createdAt: Date = Date.now

    init(date: Date, weightKg: Double, note: String = "") {
        self.id = UUID()
        self.date = date
        self.weightKg = weightKg
        self.note = note
        self.createdAt = .now
    }
}

/// Exercise the owner logged. Calories burned are typed in by the owner.
@Model
final class ExerciseEntry {
    @Attribute(.unique) var id: UUID = UUID()
    var day: Date = Calendar.current.startOfDay(for: .now)
    var createdAt: Date = Date.now
    var name: String = ""
    var minutes: Double = 0
    var kcal: Double = 0

    init(name: String, minutes: Double, kcal: Double, day: Date) {
        self.id = UUID()
        self.day = Calendar.current.startOfDay(for: day)
        self.createdAt = .now
        self.name = name
        self.minutes = minutes
        self.kcal = kcal
    }
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        UserProfile.self, DiaryEntry.self, WaterEntry.self, CustomFood.self, SavedMeal.self, UserRecipe.self, FavoriteItem.self,
        WeightEntry.self, ExerciseEntry.self,
    ]
}

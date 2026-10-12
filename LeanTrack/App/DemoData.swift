#if DEBUG
import Foundation
import SwiftData

/// Demo profile and two weeks of history for the automated screenshot tests (`-LTDemoData`).
/// Debug builds only, in a throwaway in-memory store; the real app never sees it.
/// Every food is a real USDA food from the built-in database, with its real portions.
enum DemoData {
    static func seed(into context: ModelContext) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)

        let profile = UserProfile()
        profile.name = "Alex"
        profile.sex = .female
        profile.birthDate = cal.date(byAdding: .year, value: -32, to: today) ?? today
        profile.heightCm = 168
        profile.startWeightKg = 86
        profile.currentWeightKg = 82.6
        profile.goalWeightKg = 72
        profile.goal = .lose
        profile.paceLbPerWeek = 1
        profile.activity = .light
        profile.macroPreset = .highProtein
        profile.setMacroPercents(protein: 30, carbs: 45, fat: 25)
        profile.weightUnit = .lb
        profile.heightUnit = .feetInches
        profile.foodUnit = .ounces
        profile.volumeUnit = .fluidOunces
        profile.waterGoalMl = NutritionMath.defaultWaterGoalMl(sex: .female)
        profile.extraGoals = ["sodium": 2300]
        profile.applyRecommendedCalories()
        profile.setupComplete = true
        context.insert(profile)

        // Weigh-ins every 3 days for 60 days, trending down with day-to-day wobble.
        let wobble = [0.3, -0.2, 0.1, 0.4, -0.3, 0.0, 0.2, -0.1, 0.3, -0.2]
        for i in 0..<20 {
            let daysAgo = 60 - i * 3
            guard let date = cal.date(byAdding: .day, value: -daysAgo, to: today)?.addingTimeInterval(7 * 3600) else { continue }
            let kg = 86 - Double(i) * 0.17 + wobble[i % wobble.count]
            context.insert(WeightEntry(date: date, weightKg: (kg * 10).rounded() / 10, note: i == 0 ? "Starting weight" : ""))
        }
        if let lastDate = cal.date(byAdding: .day, value: 0, to: today)?.addingTimeInterval(7 * 3600) {
            context.insert(WeightEntry(date: lastDate, weightKg: profile.currentWeightKg))
        }

        guard let db = FoodDatabase.shared else { try? context.save(); return }
        func portion(_ fdcID: Int, _ amount: Double? = nil) -> FoodPortion? {
            guard let food = db.food(id: fdcID) else { return nil }
            var p = FoodPortion.defaultFor(food, database: db)
            if let amount { p.amount = amount }
            return p
        }

        // FDC IDs from the Common list (scripts/data/common-foods.json).
        let egg = 2707152, oats = 2708489, chicken = 171477, rice = 2708408, broccoli = 169967, banana = 2709224
        let yogurt = 2705424, almonds = 2346393, salmon = 175168, sweetPotato = 168483, apple = 171688
        let bread = 2707709, peanutButter = 172470, spinach = 2709614, strawberries = 2346409, milk = 746778

        let rotations: [[(MealSlot, Int, Double?)]] = [
            [(.breakfast, egg, 2), (.breakfast, oats, nil), (.lunch, chicken, 6), (.lunch, rice, nil), (.lunch, broccoli, nil), (.snacks, banana, nil),
             (.dinner, salmon, nil), (.dinner, sweetPotato, nil), (.dinner, spinach, 2)],
            [(.breakfast, yogurt, nil), (.breakfast, strawberries, nil), (.lunch, bread, 2), (.lunch, peanutButter, nil), (.lunch, apple, nil),
             (.snacks, almonds, nil), (.dinner, chicken, 5), (.dinner, rice, nil), (.dinner, broccoli, nil)],
            [(.breakfast, egg, 3), (.breakfast, bread, 1), (.breakfast, milk, nil), (.lunch, salmon, nil), (.lunch, rice, nil),
             (.snacks, yogurt, nil), (.dinner, chicken, 6), (.dinner, sweetPotato, nil), (.dinner, broccoli, nil)],
        ]

        for daysAgo in (0...13).reversed() {
            guard let day = cal.date(byAdding: .day, value: -daysAgo, to: today) else { continue }
            var items = rotations[daysAgo % rotations.count]
            if daysAgo == 0 { items = Array(items.prefix(6)) } // today: dinner not logged yet
            for (index, item) in items.enumerated() {
                guard let p = portion(item.1, item.2) else { continue }
                let entry = DiaryEntry(portion: p, meal: item.0, day: day)
                entry.createdAt = day.addingTimeInterval(Double(7 * 3600 + index * 1800))
                context.insert(entry)
            }
            for cup in 0..<(daysAgo == 0 ? 4 : 7) {
                let water = WaterEntry(milliliters: UnitConversion.milliliters(fromFluidOunces: 8), day: day)
                water.createdAt = day.addingTimeInterval(Double(8 * 3600 + cup * 5400))
                context.insert(water)
            }
            if daysAgo % 2 == 0 {
                context.insert(ExerciseEntry(name: "Walking", minutes: 35, kcal: 140, day: day))
            }
        }

        for id in [chicken, oats, banana] {
            if let p = portion(id) { context.insert(FavoriteItem(food: p.food)) }
        }
        if let recipe = RecipeLibrary.shared?.recipes.first(where: { $0.photo != nil }) {
            context.insert(FavoriteItem(food: LoggedFood.fromRecipe(recipe)))
        }

        let bar = CustomFood()
        bar.name = "Protein bar"
        bar.brand = "Store brand"
        bar.servingName = "1 bar"
        bar.servingGrams = 60
        bar.nutrientsPerServing = Nutrients(kcal: 210, protein: 20, carbs: 22, fat: 7, fiber: 5, sugar: 3)
        context.insert(bar)

        let mealItems = [portion(chicken, 6), portion(rice), portion(broccoli)].compactMap { $0 }
        context.insert(SavedMeal(name: "Chicken, Rice & Broccoli", items: mealItems))

        try? context.save()
    }
}
#endif

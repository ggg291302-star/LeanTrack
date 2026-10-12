import Foundation
import SwiftData

/// Reading and writing the diary.
enum DiaryService {
    @discardableResult
    static func add(_ portion: FoodPortion, meal: MealSlot, day: Date, in context: ModelContext) -> DiaryEntry {
        let entry = DiaryEntry(portion: portion, meal: meal, day: day)
        context.insert(entry)
        try? context.save()
        return entry
    }

    /// Logs every item of a saved meal or a list of portions as separate entries.
    static func add(_ portions: [FoodPortion], meal: MealSlot, day: Date, in context: ModelContext) {
        for p in portions { context.insert(DiaryEntry(portion: p, meal: meal, day: day)) }
        try? context.save()
    }

    /// Logs a food. A saved meal is logged as its separate foods (times the number of servings),
    /// so each one can be edited later.
    static func log(_ portion: FoodPortion, meal: MealSlot, day: Date, in context: ModelContext) {
        if portion.food.kind == .savedMeal, let saved = savedMeal(id: portion.food.refID, in: context), !saved.items.isEmpty {
            let factor = portion.unit.name == "serving" ? portion.amount : 1
            add(saved.items.map { item in
                var copy = item
                copy.id = UUID()
                copy.amount *= factor
                return copy
            }, meal: meal, day: day, in: context)
        } else {
            add(portion, meal: meal, day: day, in: context)
        }
    }

    static func savedMeal(id: String?, in context: ModelContext) -> SavedMeal? {
        guard let id = id.flatMap({ UUID(uuidString: $0) }) else { return nil }
        return try? context.fetch(FetchDescriptor<SavedMeal>(predicate: #Predicate { $0.id == id })).first
    }

    static func customFood(id: String?, in context: ModelContext) -> CustomFood? {
        guard let id = id.flatMap({ UUID(uuidString: $0) }) else { return nil }
        return try? context.fetch(FetchDescriptor<CustomFood>(predicate: #Predicate { $0.id == id })).first
    }

    static func userRecipe(id: String?, in context: ModelContext) -> UserRecipe? {
        guard let id = id.flatMap({ UUID(uuidString: $0) }) else { return nil }
        return try? context.fetch(FetchDescriptor<UserRecipe>(predicate: #Predicate { $0.id == id })).first
    }

    static func entries(on day: Date, in context: ModelContext) -> [DiaryEntry] {
        let start = Calendar.current.startOfDay(for: day)
        let descriptor = FetchDescriptor<DiaryEntry>(predicate: #Predicate { $0.day == start }, sortBy: [SortDescriptor(\.createdAt)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Copies entries to another meal and/or day (the originals stay).
    static func copy(_ entries: [DiaryEntry], to meal: MealSlot, day: Date, in context: ModelContext) {
        for e in entries {
            var portion = e.portion
            portion.id = UUID()
            context.insert(DiaryEntry(portion: portion, meal: meal, day: day))
        }
        try? context.save()
    }

    static func move(_ entry: DiaryEntry, to meal: MealSlot, day: Date, in context: ModelContext) {
        entry.meal = meal
        entry.day = Calendar.current.startOfDay(for: day)
        try? context.save()
    }

    static func delete(_ entry: DiaryEntry, in context: ModelContext) {
        context.delete(entry)
        try? context.save()
    }

    /// Calories and macros for a set of entries.
    static func totals(_ entries: [DiaryEntry]) -> (kcal: Double, protein: Double, carbs: Double, fat: Double) {
        var kcal = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0
        for e in entries { kcal += e.kcal; protein += e.protein; carbs += e.carbs; fat += e.fat }
        return (kcal, protein, carbs, fat)
    }

    /// Most recently logged distinct foods, newest first, with the amount last used.
    static func recent(limit: Int = 40, in context: ModelContext) -> [FoodPortion] {
        var descriptor = FetchDescriptor<DiaryEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 400
        var seen = Set<String>()
        var result: [FoodPortion] = []
        for e in (try? context.fetch(descriptor)) ?? [] {
            let p = e.portion
            let key = FavoriteItem.key(for: p.food)
            if seen.insert(key).inserted { result.append(p) }
            if result.count >= limit { break }
        }
        return result
    }

    // MARK: Favorites

    static func isFavorite(_ food: LoggedFood, in context: ModelContext) -> Bool {
        let key = FavoriteItem.key(for: food)
        let descriptor = FetchDescriptor<FavoriteItem>(predicate: #Predicate { $0.key == key })
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    static func toggleFavorite(_ food: LoggedFood, in context: ModelContext) {
        let key = FavoriteItem.key(for: food)
        let descriptor = FetchDescriptor<FavoriteItem>(predicate: #Predicate { $0.key == key })
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            for item in existing { context.delete(item) }
        } else {
            context.insert(FavoriteItem(food: food))
        }
        try? context.save()
    }

    // MARK: Water

    static func water(on day: Date, in context: ModelContext) -> Double {
        let start = Calendar.current.startOfDay(for: day)
        let descriptor = FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.day == start })
        return ((try? context.fetch(descriptor)) ?? []).reduce(0) { $0 + $1.milliliters }
    }

    // MARK: Streak

    /// Days logged in a row, ending today (or yesterday, if nothing is logged yet today).
    static func streak(today: Date = .now, loggedDays: Set<Date>, calendar: Calendar = .current) -> Int {
        var day = calendar.startOfDay(for: today)
        if !loggedDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day), loggedDays.contains(yesterday) else { return 0 }
            day = yesterday
        }
        var count = 0
        while loggedDays.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }
}

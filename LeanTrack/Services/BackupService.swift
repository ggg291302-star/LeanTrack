import Foundation
import SwiftData

/// Backup & Restore: everything the owner saved, as one JSON file they keep in Files, iCloud Drive, etc.
/// API keys are never included (they stay in the Keychain).
struct BackupFile: Codable {
    struct Profile: Codable {
        var name, sexRaw: String
        var birthDate: Date
        var heightCm, currentWeightKg, startWeightKg, goalWeightKg: Double
        var activityRaw, goalRaw: String
        var paceLbPerWeek: Double
        var pregnantOrBreastfeeding: Bool
        var calorieGoal: Int
        var calorieGoalIsManual: Bool
        var proteinPercent, carbsPercent, fatPercent: Double
        var macroPresetRaw: String
        var fiberGoalG, waterGoalMl: Double
        var weightUnitRaw, heightUnitRaw, foodUnitRaw, volumeUnitRaw: String
        var exerciseAddsBack, setupComplete: Bool
        var createdAt: Date
        var waistCm: Double?
        var extraGoals: [String: Double]?
    }
    struct Diary: Codable { var id: UUID; var day, createdAt: Date; var meal: String; var portion: FoodPortion }
    struct Water: Codable { var id: UUID; var day, createdAt: Date; var milliliters: Double }
    struct Weight: Codable { var id: UUID; var date, createdAt: Date; var weightKg: Double; var note: String }
    struct Exercise: Codable { var id: UUID; var day, createdAt: Date; var name: String; var minutes, kcal: Double }
    struct Custom: Codable {
        var id: UUID; var name, brand, barcode, servingName: String; var servingGrams: Double; var nutrients: Nutrients; var createdAt: Date
    }
    struct Meal: Codable { var id: UUID; var name: String; var items: [FoodPortion]; var createdAt: Date }
    struct MyRecipe: Codable { var id: UUID; var title: String; var servings: Int; var items: [FoodPortion]; var steps: String; var createdAt: Date }
    struct Favorite: Codable { var food: LoggedFood; var createdAt: Date }

    var format = "LeanTrack backup"
    var version = 1
    var exportedAt = Date()
    var appVersion = ""
    var profile: Profile?
    var diary: [Diary] = []
    var water: [Water] = []
    var weights: [Weight] = []
    var exercise: [Exercise] = []
    var customFoods: [Custom] = []
    var savedMeals: [Meal] = []
    var myRecipes: [MyRecipe] = []
    var favorites: [Favorite] = []

    var summary: String {
        "\(diary.count) diary entries, \(weights.count) weigh-ins, \(water.count) water entries, \(customFoods.count) custom foods, \(savedMeals.count) saved meals, \(myRecipes.count) recipes"
    }
}

enum BackupService {
    enum BackupError: LocalizedError {
        case notABackup, newerVersion
        var errorDescription: String? {
            switch self {
            case .notABackup: "That file isn't a LeanTrack backup."
            case .newerVersion: "That backup was made by a newer version of LeanTrack. Update the app first."
            }
        }
    }

    static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    static func makeBackup(from context: ModelContext) throws -> BackupFile {
        var file = BackupFile()
        file.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        if let p = try context.fetch(FetchDescriptor<UserProfile>()).first {
            file.profile = BackupFile.Profile(name: p.name, sexRaw: p.sexRaw, birthDate: p.birthDate, heightCm: p.heightCm, currentWeightKg: p.currentWeightKg,
                                 startWeightKg: p.startWeightKg, goalWeightKg: p.goalWeightKg, activityRaw: p.activityRaw, goalRaw: p.goalRaw,
                                 paceLbPerWeek: p.paceLbPerWeek, pregnantOrBreastfeeding: p.pregnantOrBreastfeeding, calorieGoal: p.calorieGoal,
                                 calorieGoalIsManual: p.calorieGoalIsManual, proteinPercent: p.proteinPercent, carbsPercent: p.carbsPercent,
                                 fatPercent: p.fatPercent, macroPresetRaw: p.macroPresetRaw, fiberGoalG: p.fiberGoalG, waterGoalMl: p.waterGoalMl,
                                 weightUnitRaw: p.weightUnitRaw, heightUnitRaw: p.heightUnitRaw, foodUnitRaw: p.foodUnitRaw,
                                 volumeUnitRaw: p.volumeUnitRaw, exerciseAddsBack: p.exerciseAddsBack, setupComplete: p.setupComplete,
                                 createdAt: p.createdAt, waistCm: p.waistCm, extraGoals: p.extraGoals)
        }
        file.diary = try context.fetch(FetchDescriptor<DiaryEntry>(sortBy: [SortDescriptor(\.createdAt)]))
            .map { BackupFile.Diary(id: $0.id, day: $0.day, createdAt: $0.createdAt, meal: $0.mealRaw, portion: $0.portion) }
        file.water = try context.fetch(FetchDescriptor<WaterEntry>(sortBy: [SortDescriptor(\.createdAt)]))
            .map { BackupFile.Water(id: $0.id, day: $0.day, createdAt: $0.createdAt, milliliters: $0.milliliters) }
        file.weights = try context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date)]))
            .map { BackupFile.Weight(id: $0.id, date: $0.date, createdAt: $0.createdAt, weightKg: $0.weightKg, note: $0.note) }
        file.exercise = try context.fetch(FetchDescriptor<ExerciseEntry>(sortBy: [SortDescriptor(\.createdAt)]))
            .map { BackupFile.Exercise(id: $0.id, day: $0.day, createdAt: $0.createdAt, name: $0.name, minutes: $0.minutes, kcal: $0.kcal) }
        file.customFoods = try context.fetch(FetchDescriptor<CustomFood>(sortBy: [SortDescriptor(\.createdAt)]))
            .map { BackupFile.Custom(id: $0.id, name: $0.name, brand: $0.brand, barcode: $0.barcode, servingName: $0.servingName,
                         servingGrams: $0.servingGrams, nutrients: $0.nutrientsPerServing, createdAt: $0.createdAt) }
        file.savedMeals = try context.fetch(FetchDescriptor<SavedMeal>(sortBy: [SortDescriptor(\.createdAt)]))
            .map { BackupFile.Meal(id: $0.id, name: $0.name, items: $0.items, createdAt: $0.createdAt) }
        file.myRecipes = try context.fetch(FetchDescriptor<UserRecipe>(sortBy: [SortDescriptor(\.createdAt)]))
            .map { BackupFile.MyRecipe(id: $0.id, title: $0.title, servings: $0.servings, items: $0.items, steps: $0.steps, createdAt: $0.createdAt) }
        file.favorites = try context.fetch(FetchDescriptor<FavoriteItem>(sortBy: [SortDescriptor(\.createdAt)]))
            .compactMap { f -> BackupFile.Favorite? in f.food.map { BackupFile.Favorite(food: $0, createdAt: f.createdAt) } }
        return file
    }

    static func encode(_ file: BackupFile) throws -> Data { try encoder.encode(file) }

    static func decode(_ data: Data) throws -> BackupFile {
        guard let file = try? decoder.decode(BackupFile.self, from: data), file.format == "LeanTrack backup" else {
            throw BackupError.notABackup
        }
        guard file.version <= 1 else { throw BackupError.newerVersion }
        return file
    }

    /// Writes a backup to a temporary file for the Share sheet.
    static func exportFile(from context: ModelContext) throws -> URL {
        let data = try encode(makeBackup(from: context))
        let name = "LeanTrack-Backup-\(Date().formatted(.iso8601.year().month().day())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Deletes everything the owner saved in the app.
    static func eraseAll(in context: ModelContext) throws {
        try context.delete(model: DiaryEntry.self)
        try context.delete(model: WaterEntry.self)
        try context.delete(model: WeightEntry.self)
        try context.delete(model: ExerciseEntry.self)
        try context.delete(model: CustomFood.self)
        try context.delete(model: SavedMeal.self)
        try context.delete(model: UserRecipe.self)
        try context.delete(model: FavoriteItem.self)
        try context.delete(model: UserProfile.self)
        try context.save()
    }

    /// Replaces all data with the backup.
    static func restore(_ file: BackupFile, into context: ModelContext) throws {
        try eraseAll(in: context)
        if let b = file.profile {
            let p = UserProfile()
            p.name = b.name; p.sexRaw = b.sexRaw; p.birthDate = b.birthDate; p.heightCm = b.heightCm
            p.currentWeightKg = b.currentWeightKg; p.startWeightKg = b.startWeightKg; p.goalWeightKg = b.goalWeightKg
            p.activityRaw = b.activityRaw; p.goalRaw = b.goalRaw; p.paceLbPerWeek = b.paceLbPerWeek
            p.pregnantOrBreastfeeding = b.pregnantOrBreastfeeding; p.calorieGoal = b.calorieGoal; p.calorieGoalIsManual = b.calorieGoalIsManual
            p.proteinPercent = b.proteinPercent; p.carbsPercent = b.carbsPercent; p.fatPercent = b.fatPercent; p.macroPresetRaw = b.macroPresetRaw
            p.fiberGoalG = b.fiberGoalG; p.waterGoalMl = b.waterGoalMl; p.weightUnitRaw = b.weightUnitRaw; p.heightUnitRaw = b.heightUnitRaw
            p.foodUnitRaw = b.foodUnitRaw; p.volumeUnitRaw = b.volumeUnitRaw; p.exerciseAddsBack = b.exerciseAddsBack
            p.setupComplete = b.setupComplete; p.createdAt = b.createdAt; p.waistCm = b.waistCm ?? 0; p.extraGoals = b.extraGoals ?? [:]
            context.insert(p)
        }
        for d in file.diary {
            let e = DiaryEntry(portion: d.portion, meal: MealSlot(rawValue: d.meal) ?? .snacks, day: d.day)
            e.id = d.id; e.createdAt = d.createdAt
            context.insert(e)
        }
        for w in file.water {
            let e = WaterEntry(milliliters: w.milliliters, day: w.day)
            e.id = w.id; e.createdAt = w.createdAt
            context.insert(e)
        }
        for w in file.weights {
            let e = WeightEntry(date: w.date, weightKg: w.weightKg, note: w.note)
            e.id = w.id; e.createdAt = w.createdAt
            context.insert(e)
        }
        for x in file.exercise {
            let e = ExerciseEntry(name: x.name, minutes: x.minutes, kcal: x.kcal, day: x.day)
            e.id = x.id; e.createdAt = x.createdAt
            context.insert(e)
        }
        for c in file.customFoods {
            let f = CustomFood()
            f.id = c.id; f.name = c.name; f.brand = c.brand; f.barcode = c.barcode; f.servingName = c.servingName
            f.servingGrams = c.servingGrams; f.nutrientsPerServing = c.nutrients; f.createdAt = c.createdAt
            context.insert(f)
        }
        for m in file.savedMeals {
            let s = SavedMeal(name: m.name, items: m.items)
            s.id = m.id; s.createdAt = m.createdAt
            context.insert(s)
        }
        for r in file.myRecipes {
            let u = UserRecipe(title: r.title, servings: r.servings, items: r.items, steps: r.steps)
            u.id = r.id; u.createdAt = r.createdAt
            context.insert(u)
        }
        for f in file.favorites {
            let item = FavoriteItem(food: f.food)
            item.createdAt = f.createdAt
            context.insert(item)
        }
        try context.save()
    }
}

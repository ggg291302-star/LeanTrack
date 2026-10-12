import XCTest
import SwiftData
@testable import LeanTrack

/// Backup/restore, saved meals and weigh-ins, using a throwaway in-memory store.
final class StorageTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: Schema(AppSchema.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    private let apple = LoggedFood(name: "Apple", detail: nil, kind: .usda, refID: "171688", group: "fruit",
                                   per100g: Nutrients(kcal: 52, protein: 0.3, carbs: 14, fat: 0.2), perServing: nil,
                                   units: [ServingUnit(name: "medium", grams: 182), .gram, .ounce], imageURL: nil)

    func testBackupRoundTrip() throws {
        let source = try makeContext()
        let profile = UserProfile()
        profile.name = "Test"
        profile.calorieGoal = 1800
        profile.extraGoals = ["sodium": 2000]
        profile.setupComplete = true
        source.insert(profile)
        source.insert(DiaryEntry(portion: FoodPortion(food: apple, amount: 1, unit: apple.units[0]), meal: .snacks, day: .now))
        source.insert(WaterEntry(milliliters: 250, day: .now))
        source.insert(WeightEntry(date: .now, weightKg: 70.5, note: "morning"))
        source.insert(ExerciseEntry(name: "Walking", minutes: 30, kcal: 120, day: .now))
        let custom = CustomFood()
        custom.name = "Bar"
        custom.barcode = "036000291452"
        custom.nutrientsPerServing = Nutrients(kcal: 200)
        source.insert(custom)
        source.insert(SavedMeal(name: "Snack", items: [FoodPortion(food: apple, amount: 2, unit: apple.units[0])]))
        source.insert(UserRecipe(title: "Apple sauce", servings: 4, items: [FoodPortion(food: apple, amount: 800, unit: .gram)], steps: "Cook."))
        source.insert(FavoriteItem(food: apple))
        try source.save()

        let data = try BackupService.encode(BackupService.makeBackup(from: source))
        let file = try BackupService.decode(data)
        XCTAssertEqual(file.diary.count, 1)
        XCTAssertEqual(file.profile?.extraGoals, ["sodium": 2000])
        XCTAssertFalse(String(decoding: data, as: UTF8.self).lowercased().contains("api_key"), "backups never contain keys")

        let target = try makeContext()
        try BackupService.restore(file, into: target)
        XCTAssertEqual(try target.fetch(FetchDescriptor<UserProfile>()).first?.calorieGoal, 1800)
        let entries = try target.fetch(FetchDescriptor<DiaryEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.kcal ?? 0, 52 * 1.82, accuracy: 1e-9)
        XCTAssertEqual(try target.fetchCount(FetchDescriptor<WaterEntry>()), 1)
        XCTAssertEqual(try target.fetch(FetchDescriptor<WeightEntry>()).first?.note, "morning")
        XCTAssertEqual(try target.fetchCount(FetchDescriptor<ExerciseEntry>()), 1)
        XCTAssertEqual(try target.fetch(FetchDescriptor<CustomFood>()).first?.barcode, "036000291452")
        XCTAssertEqual(try target.fetch(FetchDescriptor<SavedMeal>()).first?.items.count, 1)
        XCTAssertEqual(try target.fetch(FetchDescriptor<UserRecipe>()).first?.servings, 4)
        XCTAssertEqual(try target.fetchCount(FetchDescriptor<FavoriteItem>()), 1)
    }

    func testRejectsFilesThatArentBackups() {
        XCTAssertThrowsError(try BackupService.decode(Data(#"{"hello":"world"}"#.utf8)))
    }

    func testEraseAll() throws {
        let context = try makeContext()
        context.insert(UserProfile())
        context.insert(WaterEntry(milliliters: 100, day: .now))
        try context.save()
        try BackupService.eraseAll(in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserProfile>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WaterEntry>()), 0)
    }

    func testSavedMealLogsEachFoodTimesServings() throws {
        let context = try makeContext()
        let meal = SavedMeal(name: "Snack", items: [FoodPortion(food: apple, amount: 1, unit: apple.units[0]),
                                                    FoodPortion(food: apple, amount: 100, unit: .gram)])
        context.insert(meal)
        try context.save()
        DiaryService.log(FoodPortion(food: meal.loggedFood, amount: 2, unit: ServingUnit(name: "serving", grams: nil)),
                         meal: .lunch, day: .now, in: context)
        let entries = try context.fetch(FetchDescriptor<DiaryEntry>())
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.map(\.amount).sorted(), [2, 200])
        XCTAssertTrue(entries.allSatisfy { $0.meal == .lunch })
    }

    func testWeighInsUpdateCurrentWeightAndOfferNewGoal() throws {
        let context = try makeContext()
        let profile = UserProfile()
        profile.sex = .male
        profile.heightCm = 180
        profile.currentWeightKg = 100
        profile.goalWeightKg = 85
        profile.goal = .lose
        profile.paceLbPerWeek = 1
        profile.applyRecommendedCalories()
        context.insert(profile)
        let before = profile.calorieGoal
        WeightService.add(weightKg: 90, date: .now, note: "", profile: profile, in: context)
        XCTAssertEqual(profile.currentWeightKg, 90)
        let suggestion = try XCTUnwrap(WeightService.suggestedCalorieUpdate(profile: profile))
        XCTAssertLessThan(suggestion, before, "10 kg lighter means a lower calorie need")
        // An older weigh-in doesn't replace the latest one.
        WeightService.add(weightKg: 95, date: .now.addingTimeInterval(-86_400 * 7), note: "", profile: profile, in: context)
        XCTAssertEqual(profile.currentWeightKg, 90)
        profile.calorieGoalIsManual = true
        XCTAssertNil(WeightService.suggestedCalorieUpdate(profile: profile), "never changes a goal the owner set by hand")
    }

    func testWeightTrend() {
        let start = Date(timeIntervalSince1970: 1_760_000_000)
        func day(_ n: Double) -> Date { start.addingTimeInterval(n * 86_400) }
        let points: [WeightTrend.Point] = [.init(date: day(0), kg: 80), .init(date: day(7), kg: 79.5), .init(date: day(14), kg: 79)]
        XCTAssertEqual(WeightTrend.kgPerWeek(points, now: day(14))!, -0.5, accuracy: 1e-9)
        let projected = WeightTrend.projectedDate(currentKg: 79, goalKg: 75, kgPerWeek: -0.5, from: day(14))
        XCTAssertEqual(projected!.timeIntervalSince(day(14)) / 86_400, 56, accuracy: 1e-6)
        XCTAssertNil(WeightTrend.projectedDate(currentKg: 79, goalKg: 75, kgPerWeek: 0.5, from: day(14)), "moving away from the goal")
        XCTAssertNil(WeightTrend.kgPerWeek(Array(points.prefix(2)), now: day(14)), "needs 3 weigh-ins")

        let avg = WeightTrend.movingAverage([.init(date: day(0), kg: 80), .init(date: day(3), kg: 79), .init(date: day(10), kg: 78)])
        XCTAssertEqual(avg.map(\.kg), [80, 79.5, 78])
    }
}

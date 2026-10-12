import XCTest
@testable import LeanTrack

final class NutritionMathTests: XCTestCase {
    func testMacroSharesUseAtwaterFactorsAndAddTo100() {
        // 50 g protein (200 kcal), 100 g carbs (400 kcal), 20 g fat (180 kcal) = 780 kcal
        let s = NutritionMath.macroShares(protein: 50, carbs: 100, fat: 20)
        XCTAssertEqual(s.protein, 200.0 / 780 * 100, accuracy: 1e-9)
        XCTAssertEqual(s.carbs, 400.0 / 780 * 100, accuracy: 1e-9)
        XCTAssertEqual(s.fat, 180.0 / 780 * 100, accuracy: 1e-9)
        XCTAssertEqual(s.protein + s.carbs + s.fat, 100, accuracy: 1e-9)
        XCTAssertEqual(NutritionMath.roundedTo100([s.protein, s.carbs, s.fat]), [26, 51, 23])
    }

    func testRoundedTo100() {
        XCTAssertEqual(NutritionMath.roundedTo100([100.0 / 3, 100.0 / 3, 100.0 / 3]).reduce(0, +), 100)
        XCTAssertEqual(NutritionMath.roundedTo100([33.3, 33.3, 33.4]), [33, 33, 34])
        XCTAssertEqual(NutritionMath.roundedTo100([0, 0, 0]), [0, 0, 0])
        let shares = NutritionMath.macroShares(protein: 0, carbs: 0, fat: 0)
        XCTAssertEqual(shares.protein + shares.carbs + shares.fat, 0)
    }

    func testRemainingOnlyAddsExerciseWhenTurnedOn() {
        XCTAssertEqual(NutritionMath.remaining(goal: 2000, eaten: 1500), 500)
        XCTAssertEqual(NutritionMath.remaining(goal: 2000, eaten: 1500, exercise: 300, addExercise: false), 500)
        XCTAssertEqual(NutritionMath.remaining(goal: 2000, eaten: 1500, exercise: 300, addExercise: true), 800)
        XCTAssertEqual(NutritionMath.remaining(goal: 2000, eaten: 2300), -300)
    }

    func testFiberAndWaterGoals() {
        XCTAssertEqual(NutritionMath.fiberGoal(calories: 2000), 28)
        XCTAssertEqual(NutritionMath.fiberGoal(calories: 1850), 26)
        XCTAssertEqual(NutritionMath.defaultWaterGoalMl(sex: .female), 2200)
        XCTAssertEqual(NutritionMath.defaultWaterGoalMl(sex: .male), 3000)
    }

    func testSumKeepsKnownValuesAndPlusHidesPartialTotals() {
        let a = Nutrients(kcal: 100, protein: 5, fiber: 2)
        let b = Nutrients(kcal: 50, protein: 1)
        let sum = NutritionMath.sum([a, b])
        XCTAssertEqual(sum.kcal, 150)
        XCTAssertEqual(sum.fiber, 2)
        XCTAssertNil(sum.sodium)
        XCTAssertNil((a + b).fiber)
    }

    func testQuantityFormatting() {
        XCTAssertEqual(Format.quantity(1.5), "1½")
        XCTAssertEqual(Format.quantity(0.25), "¼")
        XCTAssertEqual(Format.quantity(2), "2")
        XCTAssertEqual(Format.calories(nil), "—")
        XCTAssertEqual(Format.grams(nil), "—")
    }

    func testStreak() {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date(timeIntervalSince1970: 1_760_000_000))
        func day(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: today)! }
        XCTAssertEqual(DiaryService.streak(today: today, loggedDays: [day(0), day(1), day(2)], calendar: cal), 3)
        // Nothing yet today: the streak still counts through yesterday.
        XCTAssertEqual(DiaryService.streak(today: today, loggedDays: [day(1), day(2)], calendar: cal), 2)
        XCTAssertEqual(DiaryService.streak(today: today, loggedDays: [day(2), day(3)], calendar: cal), 0)
        XCTAssertEqual(DiaryService.streak(today: today, loggedDays: [day(0), day(2)], calendar: cal), 1)
    }

    func testNutrientTableCoversEveryNutrientOnce() {
        XCTAssertEqual(NutrientInfo.all.count, Nutrients.allKeyPaths.count)
        XCTAssertEqual(Set(NutrientInfo.all.map(\.key)), Set(Nutrients.columns))
        let sectionKeys = NutrientInfo.sections.flatMap(\.keys)
        XCTAssertEqual(sectionKeys.count, Set(sectionKeys).count)
        XCTAssertEqual(Set(sectionKeys), Set(Nutrients.columns))
        for key in NutrientInfo.goalCandidates { XCTAssertNotNil(NutrientInfo.info(for: key), key) }
    }

    func testFDADailyValues() {
        XCTAssertEqual(NutrientInfo.info(for: "sodium")?.dailyValue, 2300)
        XCTAssertEqual(NutrientInfo.info(for: "fiber")?.dailyValue, 28)
        XCTAssertEqual(NutrientInfo.info(for: "sat_fat")?.dailyValue, 20)
        XCTAssertEqual(NutrientInfo.info(for: "vit_d")?.dailyValue, 20)
        XCTAssertEqual(NutrientInfo.info(for: "potassium")?.dailyValue, 4700)
        XCTAssertEqual(NutrientInfo.info(for: "sodium")?.percentDV(1150), 50)
    }

    func testUnitConversionForNutrients() {
        XCTAssertEqual(NutrientInfo.convert(1, from: "G", to: "mg"), 1000)
        XCTAssertEqual(NutrientInfo.convert(250, from: "MG", to: "g"), 0.25)
        XCTAssertEqual(NutrientInfo.convert(5, from: "UG", to: "µg"), 5)
        XCTAssertEqual(NutrientInfo.convert(1000, from: "kJ", to: "kcal")!, 1000 / 4.184, accuracy: 1e-9)
        XCTAssertNil(NutrientInfo.convert(400, from: "IU", to: "µg"))
        XCTAssertNil(NutrientInfo.convert(1, from: "G", to: "kcal"))
    }
}

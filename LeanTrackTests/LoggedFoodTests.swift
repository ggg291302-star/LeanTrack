import XCTest
@testable import LeanTrack

final class LoggedFoodTests: XCTestCase {
    private let chicken = LoggedFood(
        name: "Chicken breast", detail: nil, kind: .usda, refID: "171477", group: "poultry",
        per100g: Nutrients(kcal: 165, protein: 31, carbs: 0, fat: 3.6), perServing: nil,
        units: [ServingUnit(name: "cup, chopped", grams: 140), .gram, .ounce], imageURL: nil)

    func testScalesPer100gByUnitGrams() throws {
        XCTAssertEqual(try XCTUnwrap(chicken.nutrients(amount: 100, unit: .gram)?.kcal), 165, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(chicken.nutrients(amount: 1, unit: chicken.units[0])?.kcal), 231, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(chicken.nutrients(amount: 3, unit: .ounce)?.protein), 31 * 3 * UnitConversion.gramsPerOunce / 100, accuracy: 1e-9)
        XCTAssertNil(chicken.nutrients(amount: 1, unit: chicken.units[0])?.fiber, "missing values stay missing")
    }

    func testServingFoods() throws {
        let recipe = LoggedFood(name: "Stew", detail: nil, kind: .recipe, refID: "x", group: "meal", per100g: nil,
                                perServing: Nutrients(kcal: 400, protein: 30), units: [ServingUnit(name: "serving", grams: nil)], imageURL: nil)
        XCTAssertEqual(try XCTUnwrap(recipe.nutrients(amount: 1.5, unit: recipe.units[0])?.kcal), 600, accuracy: 1e-9)
        XCTAssertNil(recipe.nutrients(amount: 100, unit: .gram), "a serving with no gram weight can't be logged in grams")
    }

    func testCustomFoodWithServingGramsCanBeLoggedInGrams() throws {
        let bar = CustomFood()
        bar.name = "Protein bar"
        bar.servingGrams = 60
        bar.nutrientsPerServing = Nutrients(kcal: 210, protein: 20)
        let food = bar.loggedFood
        XCTAssertEqual(food.units.map(\.name), ["serving", "g", "oz"])
        XCTAssertEqual(try XCTUnwrap(food.nutrients(amount: 30, unit: .gram)?.kcal), 105, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(food.nutrients(amount: 2, unit: food.units[0])?.protein), 40, accuracy: 1e-9)
    }

    func testDefaultPortions() {
        XCTAssertEqual(FoodPortion.defaultFor(chicken).unit.name, "cup, chopped")
        XCTAssertEqual(FoodPortion.defaultFor(chicken).amount, 1)
        var gramsOnly = chicken
        gramsOnly.units = [.gram, .ounce]
        XCTAssertEqual(FoodPortion.defaultFor(gramsOnly).amount, 100)
    }

    func testCommonFoodsUseTheirCommonNameAndPortion() throws {
        let db = try XCTUnwrap(FoodDatabase.shared)
        let common = try XCTUnwrap(db.commonFoods().first)
        let food = try XCTUnwrap(db.food(id: common.foodID))
        let portion = FoodPortion.defaultFor(food, database: db)
        XCTAssertEqual(portion.food.name, common.name)
        XCTAssertEqual(portion.amount, common.portion.amount)
        XCTAssertEqual(try XCTUnwrap(portion.grams), common.portion.grams, accuracy: 0.5)
    }

    func testDiaryEntryCachesTotals() {
        let entry = DiaryEntry(portion: FoodPortion(food: chicken, amount: 200, unit: .gram), meal: .lunch, day: .now)
        XCTAssertEqual(entry.kcal, 330, accuracy: 1e-9)
        XCTAssertEqual(entry.protein, 62, accuracy: 1e-9)
        XCTAssertEqual(entry.portion.amount, 200)
        XCTAssertEqual(entry.name, "Chicken breast")
    }

    func testLoggedFoodDecodesWithoutNewFields() throws {
        // Diary entries saved before `barcode` existed must still load.
        let json = #"{"name":"Apple","kind":"usda","group":"fruit","units":[{"name":"g","grams":1}]}"#
        let food = try JSONDecoder().decode(LoggedFood.self, from: Data(json.utf8))
        XCTAssertNil(food.barcode)
        XCTAssertEqual(food.name, "Apple")
    }
}

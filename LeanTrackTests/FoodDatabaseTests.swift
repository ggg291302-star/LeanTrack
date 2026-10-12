import XCTest
@testable import LeanTrack

final class FoodDatabaseTests: XCTestCase {
    private var db: FoodDatabase!

    override func setUpWithError() throws {
        db = try XCTUnwrap(FoodDatabase.shared, "foods.sqlite must be bundled in the app")
    }

    func testDatabaseHasAllThreeUSDADatasets() {
        XCTAssertGreaterThan(db.foodCount, 13_000)
        XCTAssertNotNil(db.meta["source.F"])
        XCTAssertNotNil(db.meta["source.S"])
        XCTAssertNotNil(db.meta["source.N"])
    }

    /// The fixture holds values fetched from USDA's live FoodData Central API
    /// (scripts/verify-foods.mjs), so this checks our database against USDA itself.
    func testTenFoodsMatchUSDAWebsite() throws {
        struct Fixture: Decodable {
            struct Item: Decodable { let fdcId: Int; let description: String; let kcal: Double?; let protein: Double?; let fat: Double?; let carbs: Double? }
            let foods: [Item]
        }
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "usda-spot-check", withExtension: "json"))
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        XCTAssertEqual(fixture.foods.count, 10)
        for item in fixture.foods {
            let food = try XCTUnwrap(db.food(id: item.fdcId), "missing \(item.description)")
            XCTAssertEqual(food.usdaName, item.description)
            if let kcal = item.kcal { XCTAssertEqual(food.nutrients.kcal ?? -1, kcal, accuracy: 0.011, item.description) }
            if let protein = item.protein { XCTAssertEqual(food.nutrients.protein ?? -1, protein, accuracy: 0.011, item.description) }
            if let fat = item.fat { XCTAssertEqual(food.nutrients.fat ?? -1, fat, accuracy: 0.011, item.description) }
            if let carbs = item.carbs { XCTAssertEqual(food.nutrients.carbs ?? -1, carbs, accuracy: 0.011, item.description) }
        }
    }

    func testRoastedChickenBreastValuesAndPortions() throws {
        // USDA FDC 171477: 165 kcal, 31 g protein, 3.57 g fat per 100 g.
        let chicken = try XCTUnwrap(db.food(id: 171477))
        XCTAssertEqual(chicken.name, "Chicken, breast, roasted")
        XCTAssertEqual(chicken.nutrients.kcal, 165)
        XCTAssertEqual(chicken.nutrients.protein, 31)
        XCTAssertEqual(chicken.nutrients.fat, 3.57)
        XCTAssertFalse(chicken.portions.isEmpty)
        XCTAssertTrue(chicken.portions.allSatisfy { $0.grams > 0 && $0.amount > 0 })
    }

    func testMissingValuesStayMissing() throws {
        // Scaling keeps "unknown" as unknown instead of turning it into 0.
        var n = Nutrients()
        n.kcal = 200
        let half = n.scaled(toGrams: 50)
        XCTAssertEqual(half.kcal, 100)
        XCTAssertNil(half.fiber)
        XCTAssertNil((half + Nutrients.zero).fiber)
    }

    func testCommonListResolves() throws {
        let common = db.commonFoods()
        XCTAssertGreaterThanOrEqual(common.count, 150)
        XCTAssertEqual(Set(common.map(\.name)).count, common.count, "Common names must be unique")
        for item in common {
            let food = try XCTUnwrap(db.food(id: item.foodID), item.name)
            XCTAssertGreaterThan(item.portion.grams, 0, item.name)
            XCTAssertNotNil(food.nutrients.kcal, item.name)
        }
    }
}

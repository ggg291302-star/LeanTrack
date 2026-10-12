import XCTest
@testable import LeanTrack

final class RecipeDataTests: XCTestCase {
    private var library: RecipeLibrary!
    private var db: FoodDatabase!

    override func setUpWithError() throws {
        library = try XCTUnwrap(RecipeLibrary.shared, "recipes.json must be bundled in the app")
        db = try XCTUnwrap(FoodDatabase.shared)
    }

    func testAtLeastOneHundredRecipes() {
        XCTAssertGreaterThanOrEqual(library.recipes.count, 100)
        XCTAssertEqual(Set(library.recipes.map(\.id)).count, library.recipes.count, "ids must be unique")
    }

    func testEveryRecipeHasASourceAndLicense() {
        for r in library.recipes {
            XCTAssertFalse(r.source.isEmpty, r.title)
            XCTAssertTrue(r.sourceURL.hasPrefix("https://"), r.title)
            XCTAssertFalse(r.license.isEmpty, r.title)
            XCTAssertTrue(r.licenseURL.hasPrefix("https://"), r.title)
            XCTAssertFalse(r.attribution.isEmpty, r.title)
            XCTAssertTrue(r.license.hasPrefix("Public domain") || r.license == "CC BY-SA 4.0", "\(r.title): \(r.license)")
        }
    }

    func testNoRecipeIsMissingNutrition() {
        for r in library.recipes {
            let n = r.nutritionPerServing
            XCTAssertGreaterThan(n.kcal ?? 0, 0, r.title)
            XCTAssertNotNil(n.protein, r.title)
            XCTAssertNotNil(n.carbs, r.title)
            XCTAssertNotNil(n.fat, r.title)
            XCTAssertEqual(r.nutritionNote, "Nutrition calculated from USDA data")
            XCTAssertGreaterThan(r.servings, 0, r.title)
            XCTAssertFalse(r.steps.isEmpty, r.title)
        }
    }

    /// Every ingredient line is either counted (USDA food + grams) or says why it isn't.
    func testEveryIngredientIsCountedOrExplained() {
        for r in library.recipes {
            for line in r.ingredients {
                XCTAssertTrue(line.isCounted || !(line.note ?? "").isEmpty, "\(r.title): \(line.text)")
                if let id = line.fdcId { XCTAssertNotNil(db.food(id: id), "\(r.title): FDC \(id)") }
            }
        }
    }

    /// Adding up the ingredients again from the database gives the stored calories.
    func testStoredNutritionMatchesIngredients() throws {
        for r in library.recipes {
            var kcal = 0.0
            for line in r.ingredients where line.isCounted {
                let food = try XCTUnwrap(db.food(id: line.fdcId!))
                kcal += (food.nutrients.kcal ?? 0) * line.grams! / 100
            }
            XCTAssertEqual(Double(r.nutritionPerServing.kcal ?? 0), kcal / Double(r.servings), accuracy: 2.5, r.title)
        }
    }

    func testEveryMealAndTagHasChoices() {
        for meal in ["breakfast", "lunch", "dinner", "snack"] {
            XCTAssertGreaterThanOrEqual(library.recipes.filter { $0.meals.contains(meal) }.count, 10, meal)
        }
        for tag in ["vegetarian", "high-protein", "low-calorie"] {
            XCTAssertGreaterThanOrEqual(library.recipes.filter { $0.tags.contains(tag) }.count, 10, tag)
        }
    }

    func testPhotosAreBundledAndOpenlyLicensed() {
        for r in library.recipes {
            guard let photo = r.photo else { continue }
            XCTAssertNotNil(RecipeLibrary.photoURL(for: r), "\(r.title): \(photo.image) missing from the app")
            XCTAssertTrue(photo.license.range(of: #"^(CC0|Public domain|PD|CC BY(-SA)? \d)"#, options: [.regularExpression, .caseInsensitive]) != nil,
                          "\(r.title): \(photo.license)")
            XCTAssertFalse(photo.artist.isEmpty, r.title)
        }
    }
}

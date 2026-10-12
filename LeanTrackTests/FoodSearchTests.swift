import XCTest
@testable import LeanTrack

final class FoodSearchTests: XCTestCase {
    private var db: FoodDatabase!

    override func setUpWithError() throws {
        db = try XCTUnwrap(FoodDatabase.shared)
    }

    private func top(_ query: String, _ n: Int = 5) -> [FoodSummary] {
        Array(db.search(query, limit: n))
    }

    func testTyposStillFindChickenBreast() {
        let results = top("chiken brest")
        XCTAssertTrue(results.contains { $0.usdaName.localizedCaseInsensitiveContains("chicken") && $0.usdaName.localizedCaseInsensitiveContains("breast") },
                      "Got: \(results.map(\.usdaName))")
    }

    func testFindsTheExactUSDAExampleFromThePrompt() {
        let results = db.search("chiken brest", limit: 50)
        XCTAssertTrue(results.contains { $0.usdaName == "Chicken, broilers or fryers, breast, meat only, cooked, roasted" })
    }

    func testSimpleWordsRankSensibly() {
        XCTAssertTrue(top("banana").contains { $0.name.lowercased().hasPrefix("banana") }, "\(top("banana").map(\.name))")
        XCTAssertTrue(top("eggs").contains { $0.name.lowercased().hasPrefix("egg") }, "\(top("eggs").map(\.name))")
        XCTAssertTrue(top("brocoli").contains { $0.name.lowercased().contains("broccoli") }, "\(top("brocoli").map(\.name))")
        XCTAssertTrue(top("oatmeal").contains { $0.name.lowercased().contains("oat") })
        XCTAssertTrue(top("pizza cheese").contains { $0.name.lowercased().contains("pizza") })
    }

    func testEmptyAndNonsenseQueries() {
        XCTAssertTrue(db.search("").isEmpty)
        XCTAssertTrue(db.search("   ").isEmpty)
        XCTAssertTrue(db.search("qzxqzxqzx").isEmpty)
    }

    func testSearchIsFast() {
        let queries = ["chicken", "chiken brest", "rice", "apple", "greek yogurt", "brocoli", "salmon", "pasta sauce",
                       "peanut butter", "milk 2%", "egg", "cheddar", "banana", "oatmeal", "beef ground", "tofu", "avocado",
                       "orange juice", "pizza", "coffee"]
        let start = Date()
        for q in queries { _ = db.search(q) }
        let perQuery = Date().timeIntervalSince(start) / Double(queries.count)
        XCTAssertLessThan(perQuery, 1.0, "Each search must take under a second (took \(perQuery) s)")
    }

    func testEditDistance() {
        func d(_ a: String, _ b: String, _ max: Int = 2) -> Int? { FoodSearchIndex.editDistance(Array(a.utf8), Array(b.utf8), max: max) }
        XCTAssertEqual(d("chiken", "chicken"), 1)
        XCTAssertEqual(d("brest", "breast"), 1)
        XCTAssertEqual(d("chikcen", "chicken"), 1) // swapped letters
        XCTAssertNil(d("apple", "banana"))
    }
}

import XCTest
@testable import LeanTrack

/// Parsing of USDA, Open Food Facts and Claude responses (no network: fixed sample responses).
final class OnlineFoodsTests: XCTestCase {
    // MARK: Barcodes

    func testCheckDigits() {
        XCTAssertTrue(Barcode.hasValidCheckDigit("4006381333931"))  // EAN-13
        XCTAssertTrue(Barcode.hasValidCheckDigit("036000291452"))   // UPC-A
        XCTAssertFalse(Barcode.hasValidCheckDigit("036000291453"))
        XCTAssertFalse(Barcode.hasValidCheckDigit("12345"))
    }

    func testUPCEExpansion() {
        XCTAssertEqual(Barcode.upcEtoUPCA("04252614"), "042100005264")
        XCTAssertTrue(Barcode.hasValidCheckDigit(Barcode.upcEtoUPCA("04252614")!))
        XCTAssertNil(Barcode.upcEtoUPCA("94252614"))
    }

    func testCandidatesAndMatching() {
        XCTAssertEqual(Barcode.candidates("036000291452"), ["036000291452", "0036000291452"])
        XCTAssertEqual(Barcode.candidates("0036000291452"), ["0036000291452", "036000291452"])
        XCTAssertTrue(Barcode.same("00036000291452", "036000291452"))
        XCTAssertFalse(Barcode.same("036000291452", "036000291453"))
        XCTAssertFalse(Barcode.same("", "000"))
    }

    // MARK: Open Food Facts

    func testOpenFoodFactsProduct() throws {
        let json = """
        {"code":"3017620422003","status":1,"product":{"product_name":"Nutella","brands":"Ferrero, Nutella",
         "serving_quantity":15,"serving_size":"15 g","image_front_small_url":"https://images.openfoodfacts.org/x.jpg",
         "nutriments":{"energy-kcal_100g":539,"proteins_100g":6.3,"carbohydrates_100g":57.5,"fat_100g":30.9,
         "sugars_100g":56.3,"saturated-fat_100g":10.6,"sodium_100g":0.0428,"salt_100g":0.107}}}
        """
        let food = try XCTUnwrap(OpenFoodFactsClient.parseProductResponse(Data(json.utf8)))
        XCTAssertEqual(food.name, "Nutella")
        XCTAssertEqual(food.detail, "Ferrero")
        XCTAssertEqual(food.kind, .openFoodFacts)
        XCTAssertEqual(food.barcode, "3017620422003")
        XCTAssertEqual(food.per100g?.kcal, 539)
        XCTAssertEqual(try XCTUnwrap(food.per100g?.sodium), 42.8, accuracy: 1e-9, "OFF sodium is in grams")
        XCTAssertNil(food.per100g?.fiber)
        XCTAssertEqual(food.units.first?.name, "serving (15 g)")
        XCTAssertEqual(try XCTUnwrap(food.nutrients(amount: 1, unit: food.units[0])?.kcal), 80.85, accuracy: 1e-9)
    }

    func testOpenFoodFactsNotFoundAndKilojoules() throws {
        XCTAssertNil(try OpenFoodFactsClient.parseProductResponse(Data(#"{"code":"1","status":0,"status_verbose":"product not found"}"#.utf8)))
        let kj = try XCTUnwrap(OpenFoodFactsClient.loggedFood(["product_name": "Bread", "nutriments": ["energy_100g": 1046.0]]))
        XCTAssertEqual(try XCTUnwrap(kj.per100g?.kcal), 250, accuracy: 0.01)
        XCTAssertNil(OpenFoodFactsClient.loggedFood(["product_name": "No energy", "nutriments": ["fat_100g": 1.0]]))
    }

    // MARK: USDA Branded

    func testUSDABrandedSearch() throws {
        let json = """
        {"totalHits":1,"foods":[{"fdcId":123,"description":"GREEK YOGURT","dataType":"Branded","gtinUpc":"818290014351",
         "brandOwner":"Chobani, Inc.","brandName":"CHOBANI","servingSize":170,"servingSizeUnit":"g","householdServingFullText":"1 container",
         "foodNutrients":[{"nutrientId":1008,"nutrientName":"Energy","unitName":"KCAL","value":59},
                          {"nutrientId":1003,"unitName":"G","value":10.0},{"nutrientId":1005,"unitName":"G","value":3.5},
                          {"nutrientId":1004,"unitName":"G","value":0.0},{"nutrientId":1093,"unitName":"MG","value":36},
                          {"nutrientId":1110,"unitName":"IU","value":40},{"nutrientId":1104,"unitName":"IU","value":100}]}]}
        """
        let items = try USDAClient.parseSearch(Data(json.utf8))
        let food = try XCTUnwrap(items.first.flatMap(USDAClient.loggedFood))
        XCTAssertEqual(food.name, "Greek Yogurt")
        XCTAssertEqual(food.detail, "Chobani")
        XCTAssertEqual(food.kind, .usdaBranded)
        XCTAssertEqual(food.refID, "123")
        XCTAssertEqual(food.per100g?.kcal, 59)
        XCTAssertEqual(food.per100g?.sodium, 36)
        XCTAssertEqual(try XCTUnwrap(food.per100g?.vitaminD), 1, accuracy: 1e-9, "40 IU vitamin D = 1 µg")
        XCTAssertNil(food.per100g?.vitaminA, "vitamin A in IU can't be converted to RAE")
        XCTAssertEqual(food.units.first, ServingUnit(name: "serving (1 container)", grams: 170))
        XCTAssertEqual(try XCTUnwrap(food.nutrients(amount: 1, unit: food.units[0])?.protein), 17, accuracy: 1e-9)
    }

    func testUSDAErrors() {
        XCTAssertThrowsError(try USDAClient.check(status: 429, data: Data())) { error in
            XCTAssertEqual(error as? OnlineFoodError, .rateLimited(source: USDAClient.source, usingDemoKey: USDAClient.usingDemoKey))
        }
        XCTAssertThrowsError(try USDAClient.check(status: 403, data: Data(#"{"error":{"code":"API_KEY_INVALID"}}"#.utf8))) { error in
            XCTAssertEqual(error as? OnlineFoodError, .badKey)
        }
        XCTAssertNoThrow(try USDAClient.check(status: 200, data: Data()))
        XCTAssertEqual(OnlineFoodError.from(URLError(.notConnectedToInternet)), .offline)
    }

    // MARK: Claude photo estimate

    func testClaudeRequestBody() throws {
        let body = try ClaudeFoodEstimator.requestBody(imageJPEG: Data([0xFF, 0xD8, 0xFF]))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "claude-opus-5-5")
        XCTAssertEqual(json["fallbacks"] as? String, "default")
        let output = try XCTUnwrap(json["output_config"] as? [String: Any])
        XCTAssertEqual((output["format"] as? [String: Any])?["type"] as? String, "json_schema")
        XCTAssertNil(json["thinking"], "thinking can't be turned off on this model, so it isn't sent")
        let message = try XCTUnwrap((json["messages"] as? [[String: Any]])?.first)
        let content = try XCTUnwrap(message["content"] as? [[String: Any]])
        XCTAssertEqual(content.first?["type"] as? String, "image")
        XCTAssertEqual((content.first?["source"] as? [String: Any])?["data"] as? String, "/9j/")
    }

    func testClaudeResponseParsing() throws {
        let inner = #"{"items":[{"name":"grilled chicken","search_terms":"chicken breast roasted","grams":150,"confidence":"high"},{"name":"white rice","search_terms":"rice white cooked","grams":180,"confidence":"medium"}],"notes":"Oil not visible."}"#
        let response: [String: Any] = [
            "type": "message", "role": "assistant", "model": "claude-opus-5-5", "stop_reason": "end_turn",
            "content": [["type": "thinking", "thinking": "", "signature": "x"], ["type": "text", "text": inner]],
        ]
        let data = try JSONSerialization.data(withJSONObject: response)
        let estimate = try ClaudeFoodEstimator.parseResponse(data, status: 200)
        XCTAssertEqual(estimate.items.count, 2)
        XCTAssertEqual(estimate.items[0].grams, 150)
        XCTAssertEqual(estimate.items[1].search_terms, "rice white cooked")
        // The suggested search terms find real foods in the built-in database.
        let db = try XCTUnwrap(FoodDatabase.shared)
        XCTAssertFalse(db.search("chicken breast roasted", limit: 5).isEmpty)
        XCTAssertFalse(db.search("rice white cooked", limit: 5).isEmpty)
    }

    func testClaudeRefusalAndErrors() throws {
        let refusalBody: [String: Any] = ["stop_reason": "refusal", "content": [Any]()]
        let refusal = try JSONSerialization.data(withJSONObject: refusalBody)
        XCTAssertThrowsError(try ClaudeFoodEstimator.parseResponse(refusal, status: 200)) { error in
            guard case ClaudeFoodEstimator.EstimateError.refused = error else { return XCTFail("\(error)") }
        }
        let auth = Data(#"{"type":"error","error":{"type":"authentication_error","message":"invalid x-api-key"}}"#.utf8)
        XCTAssertThrowsError(try ClaudeFoodEstimator.parseResponse(auth, status: 401)) { error in
            guard case ClaudeFoodEstimator.EstimateError.badKey = error else { return XCTFail("\(error)") }
        }
        XCTAssertThrowsError(try ClaudeFoodEstimator.parseResponse(Data(), status: 529)) { error in
            guard case ClaudeFoodEstimator.EstimateError.overloaded = error else { return XCTFail("\(error)") }
        }
    }

    func testVisionLabelCleanup() {
        XCTAssertEqual(FoodRecognizer.cleanLabel("fried_egg"), "fried egg")
        XCTAssertTrue(FoodRecognizer.ignoredLabels.contains("tableware"))
    }
}

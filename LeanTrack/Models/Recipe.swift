import Foundation

/// A bundled recipe (Resources/Data/recipes.json, built by scripts/recipes/build-recipes.mjs).
/// Nutrition is calculated from the ingredients with USDA data, per serving.
struct Recipe: Codable, Identifiable, Hashable, Sendable {
    struct Ingredient: Codable, Hashable, Sendable {
        var text: String
        var fdcId: Int?
        var grams: Double?
        /// Why a line isn't counted ("to taste", "optional"...), or a note about how it was counted.
        var note: String?

        var isCounted: Bool { fdcId != nil && grams != nil }
    }

    struct Photo: Codable, Hashable, Sendable {
        var image: String       // file name in Resources/RecipePhotos
        var file: String        // Wikimedia Commons file name
        var pageURL: String
        var artist: String
        var license: String
        var licenseURL: String?
    }

    var id: String
    var title: String
    var summary: String?
    var source: String
    var sourceURL: String
    var license: String
    var licenseURL: String
    var attribution: String
    var servings: Int
    var servingSize: String?
    var prepMinutes: Int?
    var cookMinutes: Int?
    var totalMinutes: Int?
    var meals: [String]
    var tags: [String]
    var ingredients: [Ingredient]
    var steps: [String]
    var tips: [String]?
    var nutritionPerServing: Nutrients
    var nutritionNote: String
    var printedNutritionPerServing: [String: Double]?
    var photo: Photo?

    var minutes: Int? {
        if let totalMinutes { return totalMinutes }
        let sum = (prepMinutes ?? 0) + (cookMinutes ?? 0)
        return sum > 0 ? sum : nil
    }
}

/// Loads the bundled recipe collection once.
struct RecipeLibrary: Sendable {
    let recipes: [Recipe]
    let generated: String

    private struct File: Decodable {
        let generated: String
        let recipes: [Recipe]
    }

    static let shared: RecipeLibrary? = try? RecipeLibrary()

    init(url: URL? = Bundle.main.url(forResource: "recipes", withExtension: "json", subdirectory: "Data")) throws {
        guard let url else { throw CocoaError(.fileNoSuchFile) }
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        recipes = file.recipes
        generated = file.generated
    }

    func recipe(id: String) -> Recipe? { recipes.first { $0.id == id } }

    /// URL of a recipe's bundled photo, if it has one.
    static func photoURL(for recipe: Recipe) -> URL? {
        guard let photo = recipe.photo else { return nil }
        let name = (photo.image as NSString).deletingPathExtension
        return Bundle.main.url(forResource: name, withExtension: "jpg", subdirectory: "RecipePhotos")
    }
}

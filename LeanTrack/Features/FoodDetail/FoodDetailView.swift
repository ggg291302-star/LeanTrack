import SwiftUI
import SwiftData

/// Food / Meal Detail: calories, macro donut, serving picker, meal picker, Add to Diary,
/// every nutrient, and where the data came from.
struct FoodDetailView: View {
    let mode: FoodChoiceMode
    /// Called after adding, with the message to show (nil when picking for an editor).
    let onDone: (String?) -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var food: LoggedFood
    @State private var amount: Double
    @State private var unit: ServingUnit
    @State private var meal: MealSlot
    @State private var editingCustomFood: CustomFood?
    @State private var editingMeal: SavedMeal?
    @State private var editingRecipe: UserRecipe?
    @State private var confirmingDelete = false
    @Query private var favorites: [FavoriteItem]

    init(portion: FoodPortion, mode: FoodChoiceMode, meal: MealSlot, onDone: @escaping (String?) -> Void) {
        self.mode = mode
        self.onDone = onDone
        _food = State(initialValue: portion.food)
        _amount = State(initialValue: portion.amount)
        _unit = State(initialValue: portion.unit)
        _meal = State(initialValue: meal)
        let key = FavoriteItem.key(for: portion.food)
        _favorites = Query(filter: #Predicate<FavoriteItem> { $0.key == key })
    }

    private var portion: FoodPortion { FoodPortion(food: food, amount: amount, unit: unit) }
    private var isMeal: Bool { food.kind == .savedMeal || food.kind == .userRecipe || food.kind == .recipe }

    var body: some View {
        let nutrients = portion.nutrients
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(nutrients)
                LTCard { NutritionSummary(nutrients: nutrients) }
                ingredients
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount").font(.headline).foregroundStyle(Theme.textPrimary)
                    ServingPicker(amount: $amount, unit: $unit, units: units)
                    if let grams = portion.grams, unit.name != "g" {
                        Text("≈ \(Format.number(grams)) g").font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
                if mode.isLogging {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meal").font(.headline).foregroundStyle(Theme.textPrimary)
                        MealPicker(meal: $meal)
                    }
                }
                NutrientFactsCard(nutrients: nutrients, title: "Nutrition Facts for \(portion.amountText)")
                SourceCard(food: food)
            }
            .padding(Theme.screenPadding)
            .padding(.bottom, 80)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .safeAreaInset(edge: .bottom) {
            Button(mode.isLogging ? "Add to Diary" : "Add") { add() }
                .buttonStyle(LTPrimaryButtonStyle())
                .disabled(amount <= 0 || food.nutrients(amount: amount, unit: unit) == nil)
                .padding(.horizontal, Theme.screenPadding)
                .padding(.vertical, 10)
                .background(Theme.background.ignoresSafeArea(edges: .bottom))
                .accessibilityIdentifier("food.add")
        }
        .navigationTitle(isMeal ? "Meal Detail" : "Food Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { menu }
        }
        .sheet(item: $editingCustomFood) { custom in
            CustomFoodEditor(food: custom) { saved in food = saved.loggedFood; resetUnitIfNeeded() }
        }
        .sheet(item: $editingMeal) { meal in
            SavedMealEditor(meal: meal) { saved in food = saved.loggedFood }
        }
        .sheet(item: $editingRecipe) { recipe in
            UserRecipeEditor(recipe: recipe) { saved in food = saved.loggedFood }
        }
        .confirmationDialog("Delete \(food.name)?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteOwnItem() }
        } message: {
            Text("Diary entries you already logged stay as they are.")
        }
    }

    private var units: [ServingUnit] {
        food.units.contains(unit) ? food.units : [unit] + food.units
    }

    // MARK: Pieces

    private func header(_ nutrients: Nutrients) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                if food.kind == .recipe, let recipe = RecipeLibrary.shared?.recipe(id: food.refID ?? "") {
                    RecipeImage(recipe: recipe, height: 150).frame(maxWidth: 240)
                } else {
                    FoodIcon(group: food.group, imageURL: food.imageURL.flatMap { URL(string: $0) }, size: 96)
                }
                Spacer()
            }
            Text(food.name).font(.title2.bold()).foregroundStyle(Theme.textPrimary)
                .accessibilityIdentifier("food.name")
            if let detail = food.detail, !detail.isEmpty {
                Text(detail).font(.subheadline).foregroundStyle(Theme.textSecondary).lineLimit(3)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Format.calories(nutrients.kcal)).font(.title.bold()).foregroundStyle(Theme.textPrimary)
                Text("calories").foregroundStyle(Theme.textSecondary)
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var ingredients: some View {
        let items: [FoodPortion] = {
            switch food.kind {
            case .savedMeal: DiaryService.savedMeal(id: food.refID, in: context)?.items ?? []
            case .userRecipe: DiaryService.userRecipe(id: food.refID, in: context)?.items ?? []
            default: []
            }
        }()
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(food.kind == .userRecipe ? "Ingredients (whole recipe)" : "Ingredients (1 serving)")
                    .font(.headline).foregroundStyle(Theme.textPrimary)
                LTCardList(items: items) { item in
                    FoodRow(portion: item)
                }
            }
        }
    }

    private var menu: some View {
        Menu {
            Button {
                DiaryService.toggleFavorite(food, in: context)
            } label: {
                Label(favorites.isEmpty ? "Add to Favorites" : "Remove from Favorites", systemImage: favorites.isEmpty ? "heart" : "heart.slash")
            }
            .accessibilityIdentifier("food.favorite")
            switch food.kind {
            case .custom:
                Button { editingCustomFood = DiaryService.customFood(id: food.refID, in: context) } label: { Label("Edit Food", systemImage: "pencil") }
                Button(role: .destructive) { confirmingDelete = true } label: { Label("Delete Food", systemImage: "trash") }
            case .savedMeal:
                Button { editingMeal = DiaryService.savedMeal(id: food.refID, in: context) } label: { Label("Edit Meal", systemImage: "pencil") }
                Button(role: .destructive) { confirmingDelete = true } label: { Label("Delete Meal", systemImage: "trash") }
            case .userRecipe:
                Button { editingRecipe = DiaryService.userRecipe(id: food.refID, in: context) } label: { Label("Edit Recipe", systemImage: "pencil") }
                Button(role: .destructive) { confirmingDelete = true } label: { Label("Delete Recipe", systemImage: "trash") }
            default:
                EmptyView()
            }
        } label: {
            Image(systemName: favorites.isEmpty ? "ellipsis" : "heart.fill")
                .frame(width: 32, height: 32)
        }
        .accessibilityLabel("More options")
        .accessibilityIdentifier("food.menu")
    }

    // MARK: Actions

    private func add() {
        switch mode {
        case .log(let day):
            DiaryService.log(portion, meal: meal, day: day, in: context)
            onDone("Added \(food.name) to \(meal.title)")
        case .pick(let onPick):
            onPick(portion)
            onDone(nil)
        }
    }

    private func resetUnitIfNeeded() {
        if !food.units.contains(unit), let first = food.units.first { unit = first; amount = 1 }
    }

    private func deleteOwnItem() {
        switch food.kind {
        case .custom: if let item = DiaryService.customFood(id: food.refID, in: context) { context.delete(item) }
        case .savedMeal: if let item = DiaryService.savedMeal(id: food.refID, in: context) { context.delete(item) }
        case .userRecipe: if let item = DiaryService.userRecipe(id: food.refID, in: context) { context.delete(item) }
        default: break
        }
        for fav in favorites { context.delete(fav) }
        try? context.save()
        dismiss()
    }
}

/// Where a food's numbers came from.
struct SourceCard: View {
    let food: LoggedFood

    var body: some View {
        LTCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Source").font(.headline).foregroundStyle(Theme.textPrimary)
                switch food.kind {
                case .usda:
                    let id = Int(food.refID ?? "") ?? 0
                    let full = FoodDatabase.shared?.food(id: id)
                    line(full?.source.displayName ?? "USDA FoodData Central")
                    if let usdaName = full?.usdaName ?? food.detail { line("USDA name: \(usdaName)") }
                    line("FDC ID: \(id)")
                    if let filled = full?.filledFromID {
                        line("Some nutrients not yet measured for this food are filled in from SR Legacy (FDC ID \(filled)).")
                    }
                    if let url = URL(string: "https://fdc.nal.usda.gov/food-details/\(id)/nutrients") {
                        Link("View on FoodData Central", destination: url).font(.subheadline)
                    }
                    line("Public domain (CC0). Values are per 100 g, scaled to your amount.")
                case .usdaBranded:
                    line("USDA Branded Foods (FoodData Central), from the brand's label data.")
                    if let detail = food.detail { line("Brand: \(detail)") }
                    if let id = food.refID {
                        line("FDC ID: \(id)")
                        if let url = URL(string: "https://fdc.nal.usda.gov/food-details/\(id)/nutrients") {
                            Link("View on FoodData Central", destination: url).font(.subheadline)
                        }
                    }
                    if let code = food.barcode { line("Barcode: \(code)") }
                case .openFoodFacts:
                    line("Open Food Facts: crowd-sourced data from package labels. Please check it against your package.")
                    if let code = food.refID {
                        line("Barcode: \(code)")
                        if let url = URL(string: "https://world.openfoodfacts.org/product/\(code)") {
                            Link("View on Open Food Facts", destination: url).font(.subheadline)
                        }
                    }
                    line("Data © Open Food Facts contributors, available under the Open Database License (ODbL). Images: CC BY-SA.")
                case .custom:
                    line("A food you entered yourself.")
                    if let code = food.barcode, !code.isEmpty { line("Barcode: \(code)") }
                case .recipe:
                    if let recipe = RecipeLibrary.shared?.recipe(id: food.refID ?? "") {
                        line("Recipe: \(recipe.source) (\(recipe.license))")
                        line("Nutrition is calculated from the ingredients with USDA data.")
                        if let url = URL(string: recipe.sourceURL) { Link("Open the original recipe", destination: url).font(.subheadline) }
                    }
                case .userRecipe:
                    line("Your recipe. Nutrition is the sum of its ingredients, divided by the number of servings.")
                case .savedMeal:
                    line("Your saved meal. Logging it adds each food separately.")
                }
            }
        }
    }

    private func line(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
    }
}

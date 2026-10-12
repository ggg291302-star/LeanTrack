import SwiftUI
import SwiftData

/// More → Recipes: search, filters, my own recipes, and the bundled collection with photos.
struct RecipesView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \UserRecipe.createdAt, order: .reverse) private var myRecipes: [UserRecipe]
    @Query private var favorites: [FavoriteItem]
    @State private var query = ""
    @State private var meal: String? = nil
    @State private var under500 = false
    @State private var highProtein = false
    @State private var quick = false
    @State private var vegetarian = false
    @State private var favoritesOnly = false
    @State private var creating = false

    private let meals: [(key: String, title: String)] = [("breakfast", "Breakfast"), ("lunch", "Lunch"), ("dinner", "Dinner"), ("snack", "Snack")]

    var body: some View {
        let favoriteIDs = Set(favorites.compactMap { $0.food }.filter { $0.kind == .recipe }.compactMap(\.refID))
        let recipes = filtered(favoriteIDs: favoriteIDs)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", selected: meal == nil) { meal = nil }
                        ForEach(meals, id: \.key) { m in
                            FilterChip(title: m.title, selected: meal == m.key) { meal = meal == m.key ? nil : m.key }
                        }
                        FilterChip(title: "♥ Favorites", selected: favoritesOnly) { favoritesOnly.toggle() }
                        FilterChip(title: "Under 500 cal", selected: under500) { under500.toggle() }
                        FilterChip(title: "25 g+ protein", selected: highProtein) { highProtein.toggle() }
                        FilterChip(title: "30 min or less", selected: quick) { quick.toggle() }
                        FilterChip(title: "Vegetarian", selected: vegetarian) { vegetarian.toggle() }
                    }
                    .padding(.horizontal, Theme.screenPadding)
                }
                .padding(.horizontal, -Theme.screenPadding)

                if query.isEmpty && !favoritesOnly {
                    HStack {
                        LTSectionHeader(title: "My Recipes")
                        Button { creating = true } label: { Label("New", systemImage: "plus") }
                            .font(.subheadline.weight(.semibold))
                            .padding(.top, 8)
                            .accessibilityIdentifier("recipes.new")
                    }
                    if myRecipes.isEmpty {
                        Text("Make your own from foods in the database: tap New.")
                            .font(.subheadline).foregroundStyle(Theme.textSecondary).padding(.horizontal, 4)
                    } else {
                        LTCardList(items: myRecipes) { r in
                            NavigationLink {
                                FoodDetailView(portion: FoodPortion.defaultFor(r.loggedFood), mode: .log(day: appState.selectedDay),
                                               meal: MealSlot.suggested(for: .now), onDone: showMessage)
                            } label: {
                                FoodRow(portion: FoodPortion.defaultFor(r.loggedFood))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                LTSectionHeader(title: "Recipes", trailing: "\(recipes.count)")
                if recipes.isEmpty {
                    LTCard { Text("No recipes match these filters.").foregroundStyle(Theme.textSecondary) }
                }
                ForEach(recipes) { recipe in
                    NavigationLink {
                        RecipeDetailView(recipe: recipe, mode: .log(day: appState.selectedDay), meal: MealSlot.suggested(for: .now), onDone: showMessage)
                    } label: {
                        RecipeCard(recipe: recipe, isFavorite: favoriteIDs.contains(recipe.id))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("recipe.\(recipe.id)")
                }
                Text("Recipes from the NHLBI (NIH, public domain) and the Wikibooks Cookbook (CC BY-SA 4.0). Photos from Wikimedia Commons; credits are on each recipe.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 24)
        }
        .background(Theme.background)
        .searchable(text: $query, prompt: "Search recipes")
        .navigationTitle("Recipes")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $creating) { UserRecipeEditor(recipe: nil) }
    }

    private func showMessage(_ message: String?) {
        if let message { appState.showToast(message) }
    }

    private func filtered(favoriteIDs: Set<String>) -> [Recipe] {
        let all = RecipeLibrary.shared?.recipes ?? []
        return all.filter { r in
            if !query.isEmpty && !(r.title.localizedCaseInsensitiveContains(query)
                                   || r.ingredients.contains { $0.text.localizedCaseInsensitiveContains(query) }) { return false }
            if let meal, !r.meals.contains(meal) { return false }
            if favoritesOnly && !favoriteIDs.contains(r.id) { return false }
            if under500 && (r.nutritionPerServing.kcal ?? .infinity) >= 500 { return false }
            if highProtein && (r.nutritionPerServing.protein ?? 0) < 25 { return false }
            if quick && (r.minutes ?? .max) > 30 { return false }
            if vegetarian && !r.tags.contains("vegetarian") { return false }
            return true
        }
    }
}

/// A recipe in the list: photo, title, calories, protein and time.
struct RecipeCard: View {
    let recipe: Recipe
    var isFavorite = false

    var body: some View {
        HStack(spacing: 12) {
            RecipeImage(recipe: recipe, height: 84, cornerRadius: 12).frame(width: 84)
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title).font(.headline).foregroundStyle(Theme.textPrimary).lineLimit(2).multilineTextAlignment(.leading)
                Text("\(Format.calories(recipe.nutritionPerServing.kcal)) cal · \(Format.grams(recipe.nutritionPerServing.protein)) g protein")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                HStack(spacing: 6) {
                    if let minutes = recipe.minutes { Label("\(minutes) min", systemImage: "clock") }
                    Text("· \(recipe.servings) servings")
                    if isFavorite { Image(systemName: "heart.fill").foregroundStyle(Theme.danger) }
                }
                .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.textSecondary)
        }
        .padding(10)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// A bundled recipe: photo, credit, servings scaler, nutrition, ingredients, steps, and Log.
struct RecipeDetailView: View {
    let recipe: Recipe
    let mode: FoodChoiceMode
    let onDone: (String?) -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @State private var servingsToMake: Int
    @State private var servingsToLog: Double = 1
    @State private var meal: MealSlot
    @Query private var favorites: [FavoriteItem]

    init(recipe: Recipe, mode: FoodChoiceMode, meal: MealSlot, onDone: @escaping (String?) -> Void) {
        self.recipe = recipe
        self.mode = mode
        self.onDone = onDone
        _servingsToMake = State(initialValue: recipe.servings)
        _meal = State(initialValue: meal)
        let key = FavoriteItem.key(for: LoggedFood.fromRecipe(recipe))
        _favorites = Query(filter: #Predicate<FavoriteItem> { $0.key == key })
    }

    private var scale: Double { Double(servingsToMake) / Double(max(recipe.servings, 1)) }

    var body: some View {
        let perServing = recipe.nutritionPerServing
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RecipeImage(recipe: recipe, height: 220)
                if let photo = recipe.photo {
                    Text("Photo: \(photo.artist), \(photo.license), via Wikimedia Commons")
                        .font(.caption2).foregroundStyle(Theme.textSecondary)
                        .onTapGesture { if let url = URL(string: photo.pageURL) { openURL(url) } }
                }
                Text(recipe.title).font(.title2.bold()).foregroundStyle(Theme.textPrimary)
                if let summary = recipe.summary, !summary.isEmpty {
                    Text(summary).foregroundStyle(Theme.textSecondary)
                }
                HStack(spacing: 14) {
                    if let p = recipe.prepMinutes { Label("Prep \(p) min", systemImage: "timer") }
                    if let c = recipe.cookMinutes { Label("Cook \(c) min", systemImage: "flame") }
                    if recipe.prepMinutes == nil && recipe.cookMinutes == nil, let m = recipe.minutes { Label("\(m) min", systemImage: "clock") }
                }
                .font(.subheadline).foregroundStyle(Theme.textSecondary)

                LTCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Per serving\(recipe.servingSize.map { " (\($0))" } ?? "")")
                            .font(.headline).foregroundStyle(Theme.textPrimary)
                        NutritionSummary(nutrients: perServing)
                    }
                }

                logBox

                LTCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Ingredients").font(.headline).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Stepper("Makes \(servingsToMake)", value: $servingsToMake, in: 1...48)
                                .fixedSize()
                                .font(.subheadline)
                                .accessibilityIdentifier("recipe.servings")
                        }
                        if servingsToMake != recipe.servings {
                            Text("Scaled ×\(Format.number(scale, decimals: 2)) from \(recipe.servings) servings. Gram amounts are scaled; recipe text is as written.")
                                .font(.caption).foregroundStyle(Theme.accent)
                        }
                        ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, ing in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(alignment: .top) {
                                    Text("•").foregroundStyle(Theme.textSecondary)
                                    Text(ing.text).foregroundStyle(Theme.textPrimary)
                                    Spacer(minLength: 4)
                                    if let g = ing.grams {
                                        Text("\(Format.number(g * scale)) g").font(.caption).foregroundStyle(Theme.textSecondary).monospacedDigit()
                                    }
                                }
                                if let note = ing.note {
                                    Text(note).font(.caption).foregroundStyle(Theme.textSecondary).padding(.leading, 14)
                                }
                            }
                        }
                    }
                }

                LTCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Steps").font(.headline).foregroundStyle(Theme.textPrimary)
                        ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)").font(.subheadline.bold()).foregroundStyle(.white)
                                    .frame(width: 24, height: 24).background(Theme.accent, in: Circle())
                                Text(step).foregroundStyle(Theme.textPrimary).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                if let tips = recipe.tips, !tips.isEmpty {
                    LTCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tips").font(.headline).foregroundStyle(Theme.textPrimary)
                            ForEach(tips, id: \.self) { Text("• \($0)").foregroundStyle(Theme.textPrimary) }
                        }
                    }
                }

                NutrientFactsCard(nutrients: perServing, title: "Nutrition Facts (1 serving)")

                LTCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Source & license").font(.headline).foregroundStyle(Theme.textPrimary)
                        Text(recipe.attribution).font(.subheadline).foregroundStyle(Theme.textSecondary)
                        Text(recipe.nutritionNote).font(.caption).foregroundStyle(Theme.textSecondary)
                        if let url = URL(string: recipe.sourceURL) { Link("Open the original recipe", destination: url).font(.subheadline) }
                        if let url = URL(string: recipe.licenseURL) { Link("License: \(recipe.license)", destination: url).font(.subheadline) }
                        if let photo = recipe.photo, let url = URL(string: photo.pageURL) {
                            Link("Photo: \(photo.file) (\(photo.license))", destination: url).font(.caption)
                        }
                    }
                }
            }
            .padding(Theme.screenPadding)
        }
        .background(Theme.background)
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    DiaryService.toggleFavorite(LoggedFood.fromRecipe(recipe), in: context)
                } label: {
                    Image(systemName: favorites.isEmpty ? "heart" : "heart.fill").foregroundStyle(favorites.isEmpty ? Theme.accent : Theme.danger)
                }
                .accessibilityLabel(favorites.isEmpty ? "Add to Favorites" : "Remove from Favorites")
                .accessibilityIdentifier("recipe.favorite")
            }
        }
    }

    private var logBox: some View {
        LTCard {
            VStack(alignment: .leading, spacing: 12) {
                Stepper(value: $servingsToLog, in: 0.25...10, step: 0.25) {
                    Text("\(Format.quantity(servingsToLog)) serving\(servingsToLog == 1 ? "" : "s") · \(Format.calories((recipe.nutritionPerServing.kcal ?? 0) * servingsToLog)) cal")
                        .foregroundStyle(Theme.textPrimary)
                }
                if mode.isLogging { MealPicker(meal: $meal) }
                Button(mode.isLogging ? "Log \(Format.quantity(servingsToLog)) serving\(servingsToLog == 1 ? "" : "s")" : "Add") { log() }
                    .buttonStyle(LTPrimaryButtonStyle())
                    .accessibilityIdentifier("recipe.log")
            }
        }
    }

    private func log() {
        let portion = FoodPortion(food: LoggedFood.fromRecipe(recipe), amount: servingsToLog, unit: ServingUnit(name: "serving", grams: nil))
        switch mode {
        case .log(let day):
            DiaryService.log(portion, meal: meal, day: day, in: context)
            onDone("Added \(recipe.title) to \(meal.title)")
        case .pick(let onPick):
            onPick(portion)
            onDone(nil)
        }
    }
}

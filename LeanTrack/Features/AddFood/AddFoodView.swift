import SwiftUI
import SwiftData
import PhotosUI

/// What choosing a food does: log it to the diary, or hand it back (recipe and meal editors).
enum FoodChoiceMode {
    case log(day: Date)
    case pick((FoodPortion) -> Void)

    var isLogging: Bool { if case .log = self { true } else { false } }
}

enum AddFoodTab: String, CaseIterable, Identifiable {
    case recent, favorites, common, recipes, myFoods, brands
    var id: String { rawValue }
    var title: String {
        switch self {
        case .recent: "Recent"
        case .favorites: "Favorites"
        case .common: "Common"
        case .recipes: "Recipes"
        case .myFoods: "My Foods"
        case .brands: "Brands"
        }
    }
}

/// The Common list as ready-to-log portions (built once).
enum CommonPortions {
    static let all: [FoodPortion] = {
        guard let db = FoodDatabase.shared else { return [] }
        return db.commonFoods().compactMap { common in db.food(id: common.foodID).map { FoodPortion.defaultFor($0, database: db) } }
    }()
}

struct AddFoodView: View {
    let mode: FoodChoiceMode
    var title = "Add Food"
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("openFoodFactsEnabled") private var openFoodFactsEnabled = true

    @State private var meal: MealSlot
    @State private var query = ""
    @State private var tab: AddFoodTab = .recent
    @State private var searchScope: SearchScope = .all
    @State private var path = NavigationPath()
    @State private var showingScanner = false
    @State private var showingPhotoOptions = false
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var photo: PickedPhoto?
    @State private var creatingCustomFood = false
    @State private var creatingMeal = false
    @FocusState private var searchFocused: Bool

    enum SearchScope: String, CaseIterable, Identifiable {
        case all, brands
        var id: String { rawValue }
        var title: String { self == .all ? "All Foods" : "Brands (online)" }
    }

    init(meal: MealSlot, day: Date) {
        mode = .log(day: day)
        _meal = State(initialValue: meal)
    }

    init(pickTitle: String, onPick: @escaping (FoodPortion) -> Void) {
        mode = .pick(onPick)
        title = pickTitle
        _meal = State(initialValue: .snacks)
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                searchBar
                if mode.isLogging { mealSelector }
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    UnderlineTabs(tabs: AddFoodTab.allCases, selection: $tab, title: \.title, idPrefix: "addFood.tab")
                    ScrollView {
                        tabContent
                            .padding(.horizontal, Theme.screenPadding)
                            .padding(.vertical, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                } else {
                    Picker("Search in", selection: $searchScope) {
                        ForEach(SearchScope.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.bottom, 8)
                    .accessibilityIdentifier("addFood.scope")
                    ScrollView {
                        Group {
                            if searchScope == .all {
                                LocalSearchResults(query: query, choose: choose, quickAdd: quickAdd) { searchScope = .brands }
                            } else {
                                BrandSearchResults(query: query, includeOpenFoodFacts: openFoodFactsEnabled, choose: choose, quickAdd: quickAdd)
                            }
                        }
                        .padding(.horizontal, Theme.screenPadding)
                        .padding(.bottom, 24)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
            .background(Theme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("addFood.cancel")
                }
                if mode.isLogging {
                    ToolbarItem(placement: .primaryAction) {
                        Button { showingScanner = true } label: { Image(systemName: "barcode.viewfinder") }
                            .accessibilityLabel("Scan a barcode")
                            .accessibilityIdentifier("addFood.barcode")
                    }
                }
            }
            .navigationDestination(for: FoodPortion.self) { portion in
                FoodDetailView(portion: portion, mode: detailMode, meal: meal, onDone: finishedDetail)
            }
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe, mode: detailMode, meal: meal, onDone: finishedDetail)
            }
        }
        .overlay(alignment: .bottom) {
            if let message = appState.toast { ToastView(message: message).padding(.bottom, 30) }
        }
        .sheet(isPresented: $showingScanner) {
            BarcodeFlowView(meal: meal, day: day, onLogged: { message in appState.showToast(message) })
        }
        .confirmationDialog("Add food from a photo", isPresented: $showingPhotoOptions) {
            Button("Take Photo") { showingCamera = true }
            Button("Choose from Library") { showingLibrary = true }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in photo = PickedPhoto(image: image) }
                .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showingLibrary, selection: $libraryItem, matching: .images)
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    photo = PickedPhoto(image: image)
                }
                libraryItem = nil
            }
        }
        .sheet(item: $photo) { picked in
            PhotoFoodView(image: picked.image, meal: meal, day: day, onLogged: { message in appState.showToast(message) })
        }
        .sheet(isPresented: $creatingCustomFood) {
            CustomFoodEditor(food: nil) { saved in path.append(FoodPortion.defaultFor(saved.loggedFood)) }
        }
        .sheet(isPresented: $creatingMeal) { SavedMealEditor(meal: nil) }
    }

    private var day: Date {
        if case .log(let day) = mode { return day }
        return appState.selectedDay
    }

    private var detailMode: FoodChoiceMode { mode }

    // MARK: Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.textSecondary).accessibilityHidden(true)
            TextField("Search for a food…", text: $query)
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .foregroundStyle(Theme.textPrimary)
                .accessibilityIdentifier("addFood.search")
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textSecondary) }
                    .accessibilityLabel("Clear search")
            }
            if mode.isLogging {
                Button { showingPhotoOptions = true } label: {
                    Image(systemName: "camera.fill").foregroundStyle(Theme.accent).frame(width: 32, height: 32)
                }
                .accessibilityLabel("Add food from a photo")
                .accessibilityIdentifier("addFood.camera")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.cardElevated, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
        .padding(.horizontal, Theme.screenPadding)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var mealSelector: some View {
        HStack {
            Text("Adding to").foregroundStyle(Theme.textSecondary)
            Menu {
                Picker("Meal", selection: $meal) {
                    ForEach(MealSlot.allCases) { Text($0.title).tag($0) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(meal.title).fontWeight(.semibold)
                    Image(systemName: "chevron.down").font(.caption.weight(.bold))
                }
            }
            .accessibilityIdentifier("addFood.meal")
            Text("· \(Format.dayTitle(day))").foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .font(.subheadline)
        .padding(.horizontal, Theme.screenPadding + 4)
        .padding(.bottom, 4)
    }

    // MARK: Tabs

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .recent: RecentFoodsList(choose: choose, quickAdd: quickAdd)
        case .favorites: FavoriteFoodsList(choose: choose, quickAdd: quickAdd)
        case .common:
            LTCardList(items: CommonPortions.all) { portion in
                FoodRow(portion: portion, onAdd: { quickAdd(portion) })
                    .onTapGesture { choose(portion) }
            }
        case .recipes: RecipesTabList(choose: choose, chooseRecipe: { path.append($0) }, quickAdd: quickAdd)
        case .myFoods:
            MyFoodsTabList(choose: choose, quickAdd: quickAdd,
                           newFood: { creatingCustomFood = true }, newMeal: { creatingMeal = true })
        case .brands:
            LTComingSoon(systemImage: "magnifyingglass",
                         title: "Search brand-name foods",
                         message: "Type a product or brand above (like \"Greek yogurt Chobani\"). LeanTrack searches USDA Branded Foods\(openFoodFactsEnabled ? " and Open Food Facts" : "") online. To look up a package, tap the barcode button.")
                .onAppear { searchScope = .brands; searchFocused = true }
        }
    }

    // MARK: Actions

    private func choose(_ portion: FoodPortion) {
        searchFocused = false
        path.append(portion)
    }

    private func quickAdd(_ portion: FoodPortion) {
        switch mode {
        case .log(let day):
            DiaryService.log(portion, meal: meal, day: day, in: context)
            appState.showToast("Added \(portion.food.name) to \(meal.title)")
        case .pick(let onPick):
            onPick(portion)
            dismiss()
        }
    }

    private func finishedDetail(_ message: String?) {
        if case .pick = mode {
            dismiss()
            return
        }
        if !path.isEmpty { path.removeLast() }
        if let message { appState.showToast(message) }
    }
}

/// A photo picked for food recognition.
struct PickedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - Lists

private struct RecentFoodsList: View {
    let choose: (FoodPortion) -> Void
    let quickAdd: (FoodPortion) -> Void
    @Query private var entries: [DiaryEntry]

    init(choose: @escaping (FoodPortion) -> Void, quickAdd: @escaping (FoodPortion) -> Void) {
        self.choose = choose
        self.quickAdd = quickAdd
        var descriptor = FetchDescriptor<DiaryEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 300
        _entries = Query(descriptor)
    }

    var body: some View {
        let recent = Self.distinct(entries)
        if recent.isEmpty {
            LTComingSoon(systemImage: "clock", title: "No recent foods yet",
                         message: "Foods you log show up here, with the amount you used last time. Try the Common tab or search above.")
        } else {
            LTCardList(items: recent) { portion in
                FoodRow(portion: portion, onAdd: { quickAdd(portion) })
                    .onTapGesture { choose(portion) }
            }
        }
    }

    static func distinct(_ entries: [DiaryEntry]) -> [FoodPortion] {
        var seen = Set<String>()
        var result: [FoodPortion] = []
        for e in entries {
            var p = e.portion
            guard seen.insert(FavoriteItem.key(for: p.food)).inserted else { continue }
            p.id = UUID()
            result.append(p)
            if result.count >= 40 { break }
        }
        return result
    }
}

private struct FavoriteFoodsList: View {
    let choose: (FoodPortion) -> Void
    let quickAdd: (FoodPortion) -> Void
    @Query(sort: \FavoriteItem.createdAt, order: .reverse) private var favorites: [FavoriteItem]

    var body: some View {
        let portions: [FoodPortion] = favorites.compactMap { item in item.food.map { FoodPortion.defaultFor($0) } }
        if portions.isEmpty {
            LTComingSoon(systemImage: "heart", title: "No favorites yet",
                         message: "Open any food or recipe and tap ••• → Add to Favorites.")
        } else {
            LTCardList(items: portions) { portion in
                FoodRow(portion: portion, onAdd: { quickAdd(portion) })
                    .onTapGesture { choose(portion) }
            }
        }
    }
}

private struct RecipesTabList: View {
    let choose: (FoodPortion) -> Void
    let chooseRecipe: (Recipe) -> Void
    let quickAdd: (FoodPortion) -> Void
    @Query(sort: \UserRecipe.createdAt, order: .reverse) private var myRecipes: [UserRecipe]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !myRecipes.isEmpty {
                LTSectionHeader(title: "My Recipes")
                LTCardList(items: myRecipes.map { FoodPortion.defaultFor($0.loggedFood) }) { portion in
                    FoodRow(portion: portion, onAdd: { quickAdd(portion) })
                        .onTapGesture { choose(portion) }
                }
            }
            LTSectionHeader(title: "Recipes", trailing: "\(RecipeLibrary.shared?.recipes.count ?? 0)")
            LTCardList(items: RecipeLibrary.shared?.recipes ?? [], dividerInset: 84) { recipe in
                let portion = FoodPortion.defaultFor(LoggedFood.fromRecipe(recipe))
                HStack(spacing: 12) {
                    RecipeImage(recipe: recipe, height: 56, cornerRadius: 10).frame(width: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(recipe.title).foregroundStyle(Theme.textPrimary).lineLimit(2)
                        Text("1 serving · \(Format.macroLine(recipe.nutritionPerServing))")
                            .font(.footnote).foregroundStyle(Theme.textSecondary).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Button { quickAdd(portion) } label: {
                        Image(systemName: "plus").font(.title3.weight(.medium)).foregroundStyle(Theme.accent).frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Quick add 1 serving of \(recipe.title)")
                }
                .padding(.leading, 14).padding(.trailing, 4).padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture { chooseRecipe(recipe) }
            }
        }
    }
}

private struct MyFoodsTabList: View {
    let choose: (FoodPortion) -> Void
    let quickAdd: (FoodPortion) -> Void
    let newFood: () -> Void
    let newMeal: () -> Void
    @Query(sort: \CustomFood.createdAt, order: .reverse) private var foods: [CustomFood]
    @Query(sort: \SavedMeal.createdAt, order: .reverse) private var meals: [SavedMeal]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button(action: newFood) { Label("Custom Food", systemImage: "plus") }
                    .buttonStyle(LTSecondaryButtonStyle())
                    .accessibilityIdentifier("addFood.newCustomFood")
                Button(action: newMeal) { Label("Meal", systemImage: "plus") }
                    .buttonStyle(LTSecondaryButtonStyle())
            }
            if !meals.isEmpty {
                LTSectionHeader(title: "Saved Meals")
                LTCardList(items: meals.map { FoodPortion.defaultFor($0.loggedFood) }) { portion in
                    FoodRow(portion: portion, onAdd: { quickAdd(portion) })
                        .onTapGesture { choose(portion) }
                }
            }
            if !foods.isEmpty {
                LTSectionHeader(title: "Custom Foods")
                LTCardList(items: foods.map { FoodPortion.defaultFor($0.loggedFood) }) { portion in
                    FoodRow(portion: portion, onAdd: { quickAdd(portion) })
                        .onTapGesture { choose(portion) }
                }
            }
            if meals.isEmpty && foods.isEmpty {
                LTComingSoon(systemImage: "fork.knife", title: "Your own foods and meals",
                             message: "Add a food from a package label, or save several foods together as a meal.")
            }
        }
    }
}

/// Built-in USDA foods, my foods, meals and recipes that match the search.
private struct LocalSearchResults: View {
    let query: String
    let choose: (FoodPortion) -> Void
    let quickAdd: (FoodPortion) -> Void
    let searchBrands: () -> Void
    @Query private var customFoods: [CustomFood]
    @Query private var meals: [SavedMeal]
    @Query private var myRecipes: [UserRecipe]
    @State private var usda: [FoodPortion] = []
    @State private var searched = ""

    init(query: String, choose: @escaping (FoodPortion) -> Void, quickAdd: @escaping (FoodPortion) -> Void, searchBrands: @escaping () -> Void) {
        self.query = query
        self.choose = choose
        self.quickAdd = quickAdd
        self.searchBrands = searchBrands
    }

    var body: some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        let mine = myMatches(q)
        let recipes: [FoodPortion] = Array((RecipeLibrary.shared?.recipes ?? []).filter { $0.title.localizedCaseInsensitiveContains(q) }.prefix(8))
            .map { FoodPortion.defaultFor(LoggedFood.fromRecipe($0)) }

        VStack(alignment: .leading, spacing: 10) {
            if !mine.isEmpty {
                LTSectionHeader(title: "My Foods")
                LTCardList(items: mine) { p in FoodRow(portion: p, onAdd: { quickAdd(p) }).onTapGesture { choose(p) } }
            }
            LTSectionHeader(title: "USDA Foods", trailing: usda.isEmpty ? nil : "\(usda.count)")
            if usda.isEmpty && searched == q {
                LTCard {
                    Text("No built-in foods match \"\(q)\". Check the spelling, try fewer words, or search brand-name foods.")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                }
            } else {
                LTCardList(items: usda) { p in FoodRow(portion: p, onAdd: { quickAdd(p) }).onTapGesture { choose(p) } }
            }
            if !recipes.isEmpty {
                LTSectionHeader(title: "Recipes")
                LTCardList(items: recipes) { p in FoodRow(portion: p, onAdd: { quickAdd(p) }).onTapGesture { choose(p) } }
            }
            Button(action: searchBrands) {
                Label("Search brand-name foods for \"\(q)\"", systemImage: "globe")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(LTSecondaryButtonStyle())
            .padding(.top, 6)
        }
        .task(id: q) {
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled, let db = FoodDatabase.shared else { return }
            usda = db.search(q, limit: 40).compactMap { db.food(id: $0.id).map { FoodPortion.defaultFor($0, database: db) } }
            searched = q
        }
    }
}

extension LocalSearchResults {
    func myMatches(_ q: String) -> [FoodPortion] {
        var result: [FoodPortion] = []
        for meal in meals where meal.name.localizedCaseInsensitiveContains(q) {
            result.append(FoodPortion.defaultFor(meal.loggedFood))
        }
        for food in customFoods where food.name.localizedCaseInsensitiveContains(q) || food.brand.localizedCaseInsensitiveContains(q) {
            result.append(FoodPortion.defaultFor(food.loggedFood))
        }
        for recipe in myRecipes where recipe.title.localizedCaseInsensitiveContains(q) {
            result.append(FoodPortion.defaultFor(recipe.loggedFood))
        }
        return result
    }
}

/// USDA Branded + Open Food Facts results (online).
private struct BrandSearchResults: View {
    let query: String
    let includeOpenFoodFacts: Bool
    let choose: (FoodPortion) -> Void
    let quickAdd: (FoodPortion) -> Void
    @State private var result: BrandSearch.Result?
    @State private var loading = false
    private static var cache: [String: BrandSearch.Result] = [:]

    var body: some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        VStack(alignment: .leading, spacing: 10) {
            if q.count < 3 {
                LTCard { Text("Type at least 3 letters to search brand-name foods.").foregroundStyle(Theme.textSecondary) }
            } else if loading && result == nil {
                HStack { Spacer(); ProgressView("Searching USDA\(includeOpenFoodFacts ? " and Open Food Facts" : "")…"); Spacer() }
                    .padding(.top, 30)
            } else if let result {
                ForEach(result.errors, id: \.self) { NoteCard(text: $0, warning: true) }
                if result.foods.isEmpty && result.errors.isEmpty {
                    LTCard { Text("No brand-name foods found for \"\(q)\".").foregroundStyle(Theme.textSecondary) }
                } else {
                    LTCardList(items: result.foods.map { FoodPortion.defaultFor($0) }) { p in
                        FoodRow(portion: p, subtitle: subtitle(p), onAdd: { quickAdd(p) })
                            .onTapGesture { choose(p) }
                    }
                }
                Text("Brand data: USDA FoodData Central (public domain)\(includeOpenFoodFacts ? " and Open Food Facts (ODbL, crowd-sourced; check against the label)" : "").")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .task(id: q) {
            guard q.count >= 3 else { return }
            let key = "\(includeOpenFoodFacts)|\(q.lowercased())"
            if let cached = Self.cache[key] { result = cached; return }
            result = nil
            // Wait for typing to pause, so each search uses only one request.
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            loading = true
            let found = await BrandSearch.search(q, includeOpenFoodFacts: includeOpenFoodFacts)
            loading = false
            guard !Task.isCancelled else { return }
            if found.errors.isEmpty { Self.cache[key] = found }
            result = found
        }
    }

    private func subtitle(_ p: FoodPortion) -> String {
        let brand = p.food.detail.map { "\($0) · " } ?? ""
        let source = p.food.kind == .openFoodFacts ? "OFF" : "USDA"
        return "\(brand)\(source) · \(p.amountText) · \(Format.calories(p.nutrients.kcal)) cal"
    }
}

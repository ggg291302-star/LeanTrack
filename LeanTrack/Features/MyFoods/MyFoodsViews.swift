import SwiftUI
import SwiftData

/// More → Custom Foods & Meals.
struct MyFoodsView: View {
    enum Kind: String, CaseIterable, Identifiable {
        case foods, meals, recipes
        var id: String { rawValue }
        var title: String {
            switch self {
            case .foods: "Custom Foods"
            case .meals: "Saved Meals"
            case .recipes: "My Recipes"
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Query(sort: \CustomFood.name) private var foods: [CustomFood]
    @Query(sort: \SavedMeal.name) private var meals: [SavedMeal]
    @Query(sort: \UserRecipe.title) private var recipes: [UserRecipe]
    @State private var kind: Kind = .foods
    @State private var editingFood: CustomFood?
    @State private var editingMeal: SavedMeal?
    @State private var editingRecipe: UserRecipe?
    @State private var creatingFood = false
    @State private var creatingMeal = false
    @State private var creatingRecipe = false

    var body: some View {
        List {
            Section {
                Picker("Show", selection: $kind) {
                    ForEach(Kind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            Section {
                switch kind {
                case .foods:
                    if foods.isEmpty { empty("No custom foods yet", "Add foods from package labels, or scan a barcode that isn't in the databases.") }
                    ForEach(foods) { food in
                        Button { editingFood = food } label: { FoodRow(portion: FoodPortion.defaultFor(food.loggedFood)) }
                            .buttonStyle(.plain)
                    }
                    .onDelete { offsets in delete(offsets.map { foods[$0] }) }
                case .meals:
                    if meals.isEmpty { empty("No saved meals yet", "Save foods you often eat together. In the Diary, use a meal's ••• menu → Save as meal.") }
                    ForEach(meals) { meal in
                        Button { editingMeal = meal } label: { FoodRow(portion: FoodPortion.defaultFor(meal.loggedFood)) }
                            .buttonStyle(.plain)
                    }
                    .onDelete { offsets in delete(offsets.map { meals[$0] }) }
                case .recipes:
                    if recipes.isEmpty { empty("No recipes of your own yet", "Build a recipe from foods in the database. LeanTrack adds up the nutrition per serving.") }
                    ForEach(recipes) { recipe in
                        Button { editingRecipe = recipe } label: { FoodRow(portion: FoodPortion.defaultFor(recipe.loggedFood)) }
                            .buttonStyle(.plain)
                    }
                    .onDelete { offsets in delete(offsets.map { recipes[$0] }) }
                }
            }
            .listRowBackground(Theme.card)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Custom Foods & Meals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { creatingFood = true } label: { Label("New Custom Food", systemImage: "carrot") }
                    Button { creatingMeal = true } label: { Label("New Meal", systemImage: "fork.knife") }
                    Button { creatingRecipe = true } label: { Label("New Recipe", systemImage: "book") }
                } label: { Image(systemName: "plus") }
                .accessibilityLabel("Add")
                .accessibilityIdentifier("myFoods.add")
            }
        }
        .sheet(item: $editingFood) { CustomFoodEditor(food: $0) }
        .sheet(item: $editingMeal) { SavedMealEditor(meal: $0) }
        .sheet(item: $editingRecipe) { UserRecipeEditor(recipe: $0) }
        .sheet(isPresented: $creatingFood) { CustomFoodEditor(food: nil) }
        .sheet(isPresented: $creatingMeal) { SavedMealEditor(meal: nil) }
        .sheet(isPresented: $creatingRecipe) { UserRecipeEditor(recipe: nil) }
    }

    private func empty(_ title: String, _ message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline).foregroundStyle(Theme.textPrimary)
            Text(message).font(.subheadline).foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
    }

    private func delete(_ models: [any PersistentModel]) {
        for m in models { context.delete(m) }
        try? context.save()
    }
}

// MARK: - Custom food

/// Type in a food from its Nutrition Facts label. Empty fields are saved as "unknown" (shown as —).
struct CustomFoodEditor: View {
    let existing: CustomFood?
    let onSave: ((CustomFood) -> Void)?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var brand = ""
    @State private var barcode = ""
    @State private var servingName = "1 serving"
    @State private var servingGrams: Double?
    @State private var values: [String: Double] = [:]
    @State private var showMore = false

    private let mainKeys = ["kcal", "protein", "carbs", "fat"]
    private let moreKeys = ["fiber", "sugar", "sat_fat", "trans_fat", "cholesterol", "sodium", "potassium", "calcium", "iron", "vit_d", "caffeine"]

    init(food: CustomFood?, barcode: String = "", onSave: ((CustomFood) -> Void)? = nil) {
        existing = food
        self.onSave = onSave
        if let food {
            _name = State(initialValue: food.name)
            _brand = State(initialValue: food.brand)
            _barcode = State(initialValue: food.barcode)
            _servingName = State(initialValue: food.servingName)
            _servingGrams = State(initialValue: food.servingGrams > 0 ? food.servingGrams : nil)
            var v: [String: Double] = [:]
            let n = food.nutrientsPerServing
            for info in NutrientInfo.all { if let value = n[keyPath: info.keyPath] { v[info.key] = value } }
            _values = State(initialValue: v)
        } else {
            _barcode = State(initialValue: barcode)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name (required)", text: $name).accessibilityIdentifier("customFood.name")
                    TextField("Brand (optional)", text: $brand)
                    TextField("Barcode (optional)", text: $barcode).keyboardType(.numberPad)
                }
                Section {
                    TextField("Serving, e.g. 1 bar or 2/3 cup", text: $servingName)
                    LabeledContent("Grams per serving") {
                        TextField("optional", value: $servingGrams, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                } header: { Text("Serving size") } footer: {
                    Text("Adding the grams lets you log this food in g and oz too.")
                }
                Section("Nutrition per serving") {
                    ForEach(mainKeys, id: \.self) { field($0) }
                }
                Section {
                    if showMore {
                        ForEach(moreKeys, id: \.self) { field($0) }
                    } else {
                        Button("Add fiber, sugar, sodium and more") { showMore = true }
                    }
                } footer: {
                    Text("Leave a field empty if the label doesn't list it. LeanTrack shows it as — instead of guessing.")
                }
            }
            .navigationTitle(existing == nil ? "New Custom Food" : "Edit Custom Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || values["kcal"] == nil)
                        .accessibilityIdentifier("customFood.save")
                }
            }
            .onAppear { if !moreKeys.allSatisfy({ values[$0] == nil }) { showMore = true } }
        }
    }

    private func field(_ key: String) -> some View {
        let info = NutrientInfo.info(for: key)
        return LabeledContent(info.map { "\($0.name) (\($0.unit == "kcal" ? "cal" : $0.unit))" } ?? key) {
            TextField(key == "kcal" ? "required" : "—", value: Binding(
                get: { values[key] },
                set: { values[key] = $0.map { max(0, $0) } }
            ), format: .number)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .accessibilityIdentifier("customFood.\(key)")
        }
    }

    private func save() {
        let food = existing ?? CustomFood()
        food.name = name.trimmingCharacters(in: .whitespaces)
        food.brand = brand.trimmingCharacters(in: .whitespaces)
        food.barcode = Barcode.digits(barcode)
        food.servingName = servingName.trimmingCharacters(in: .whitespaces).isEmpty ? "1 serving" : servingName
        food.servingGrams = servingGrams ?? 0
        var n = Nutrients()
        for info in NutrientInfo.all { n[keyPath: info.keyPath] = values[info.key] }
        food.nutrientsPerServing = n
        if existing == nil { context.insert(food) }
        try? context.save()
        onSave?(food)
        dismiss()
    }
}

// MARK: - Saved meal

struct SavedMealEditor: View {
    let existing: SavedMeal?
    let onSave: ((SavedMeal) -> Void)?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var items: [FoodPortion]
    @State private var picking = false
    @State private var editingIndex: Int?

    init(meal: SavedMeal?, onSave: ((SavedMeal) -> Void)? = nil) {
        existing = meal
        self.onSave = onSave
        _name = State(initialValue: meal?.name ?? "")
        _items = State(initialValue: meal?.items ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("e.g. Chicken, Rice & Broccoli", text: $name) }
                PortionListSection(title: "Foods", items: $items, picking: $picking, editingIndex: $editingIndex)
                Section("Total") { MacroTotalsRow(nutrients: NutritionMath.sum(items.map(\.nutrients))) }
            }
            .navigationTitle(existing == nil ? "New Meal" : "Edit Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let meal = existing ?? SavedMeal(name: "", items: [])
                        meal.name = name.trimmingCharacters(in: .whitespaces)
                        meal.items = items
                        if existing == nil { context.insert(meal) }
                        try? context.save()
                        onSave?(meal)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || items.isEmpty)
                }
            }
            .sheet(isPresented: $picking) {
                AddFoodView(pickTitle: "Add to Meal") { items.append($0) }
            }
            .sheet(item: Binding(get: { editingIndex.map(EditIndex.init) }, set: { editingIndex = $0?.index })) { edit in
                PortionAmountSheet(portion: $items[edit.index])
            }
        }
    }
}

// MARK: - User recipe

struct UserRecipeEditor: View {
    let existing: UserRecipe?
    let onSave: ((UserRecipe) -> Void)?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var servings: Int
    @State private var items: [FoodPortion]
    @State private var steps: String
    @State private var picking = false
    @State private var editingIndex: Int?

    init(recipe: UserRecipe?, onSave: ((UserRecipe) -> Void)? = nil) {
        existing = recipe
        self.onSave = onSave
        _title = State(initialValue: recipe?.title ?? "")
        _servings = State(initialValue: recipe?.servings ?? 4)
        _items = State(initialValue: recipe?.items ?? [])
        _steps = State(initialValue: recipe?.steps ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe") {
                    TextField("Title", text: $title).accessibilityIdentifier("userRecipe.title")
                    Stepper("Makes \(servings) serving\(servings == 1 ? "" : "s")", value: $servings, in: 1...48)
                }
                PortionListSection(title: "Ingredients", items: $items, picking: $picking, editingIndex: $editingIndex)
                Section("Per serving") {
                    MacroTotalsRow(nutrients: NutritionMath.sum(items.map(\.nutrients)).scaled(by: 1 / Double(max(servings, 1))))
                }
                Section("Steps (optional)") {
                    TextEditor(text: $steps).frame(minHeight: 120)
                }
            }
            .navigationTitle(existing == nil ? "New Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let recipe = existing ?? UserRecipe(title: "", servings: servings, items: [], steps: "")
                        recipe.title = title.trimmingCharacters(in: .whitespaces)
                        recipe.servings = servings
                        recipe.items = items
                        recipe.steps = steps
                        if existing == nil { context.insert(recipe) }
                        try? context.save()
                        onSave?(recipe)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || items.isEmpty)
                }
            }
            .sheet(isPresented: $picking) {
                AddFoodView(pickTitle: "Add Ingredient") { items.append($0) }
            }
            .sheet(item: Binding(get: { editingIndex.map(EditIndex.init) }, set: { editingIndex = $0?.index })) { edit in
                PortionAmountSheet(portion: $items[edit.index])
            }
        }
    }
}

// MARK: - Shared pieces

struct EditIndex: Identifiable {
    let index: Int
    var id: Int { index }
}

/// A Form section listing portions, with Add, tap-to-edit and swipe-to-delete.
struct PortionListSection: View {
    let title: String
    @Binding var items: [FoodPortion]
    @Binding var picking: Bool
    @Binding var editingIndex: Int?

    var body: some View {
        Section(title) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                Button { editingIndex = index } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.food.name).foregroundStyle(Theme.textPrimary)
                            Text("\(item.amountText) · \(Format.calories(item.nutrients.kcal)) cal").font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .onDelete { items.remove(atOffsets: $0) }
            Button { picking = true } label: { Label("Add Food", systemImage: "plus") }
                .accessibilityIdentifier("portionList.add")
        }
    }
}

/// Change the amount of one item in a meal or recipe.
struct PortionAmountSheet: View {
    @Binding var portion: FoodPortion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(portion.food.name).font(.title3.bold()).foregroundStyle(Theme.textPrimary)
                ServingPicker(amount: $portion.amount, unit: $portion.unit, units: portion.food.units)
                LTCard { NutritionSummary(nutrients: portion.nutrients) }
                Spacer()
            }
            .padding(Theme.screenPadding)
            .background(Theme.background)
            .navigationTitle("Amount")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}

/// "540 cal · 55 g P · 49 g C · 11 g F" for a total.
struct MacroTotalsRow: View {
    let nutrients: Nutrients
    var body: some View {
        HStack {
            Text("\(Format.calories(nutrients.kcal ?? 0)) cal").font(.headline).foregroundStyle(Theme.textPrimary)
            Spacer()
            HStack(spacing: 10) {
                Text("\(Format.grams(nutrients.protein ?? 0))g P").foregroundStyle(Theme.protein)
                Text("\(Format.grams(nutrients.carbs ?? 0))g C").foregroundStyle(Theme.carbs)
                Text("\(Format.grams(nutrients.fat ?? 0))g F").foregroundStyle(Theme.fat)
            }
            .font(.subheadline.weight(.semibold))
        }
    }
}

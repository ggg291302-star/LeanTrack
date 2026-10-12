import SwiftUI
import SwiftData

/// Food from a photo. With an Anthropic API key, Claude splits the plate into foods and estimates
/// each one's weight; LeanTrack matches them to USDA foods for the calories. Without a key (or as a
/// backup), Apple's on-device classifier suggests what the food is.
struct PhotoFoodView: View {
    let image: UIImage
    let day: Date
    let onLogged: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var meal: MealSlot
    @State private var guesses: [FoodRecognizer.Guess] = []
    @State private var classifying = true
    @State private var ai: AIState = .idle
    @State private var items: [AIItem] = []
    @State private var notes = ""
    @State private var hasKey = KeychainStore.has(.anthropicAPIKey)
    @State private var path = NavigationPath()

    enum AIState: Equatable { case idle, running, done, failed(String) }

    struct AIItem: Identifiable {
        let id = UUID()
        var name: String
        var grams: Double
        var confidence: String
        var matches: [Food]
        var selected = 0
        var include = true

        var food: Food? { matches.indices.contains(selected) ? matches[selected] : nil }
        var nutrients: Nutrients? { food?.nutrients.scaled(toGrams: grams) }
    }

    init(image: UIImage, meal: MealSlot, day: Date, onLogged: @escaping (String) -> Void) {
        self.image = image
        self.day = day
        self.onLogged = onLogged
        _meal = State(initialValue: meal)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                        .accessibilityLabel("Your food photo")
                    MealPicker(meal: $meal)
                    aiSection
                    onDeviceSection
                }
                .padding(Theme.screenPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle("Food Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .navigationDestination(for: FoodPortion.self) { portion in
                FoodDetailView(portion: portion, mode: .log(day: day), meal: meal) { message in
                    if let message { onLogged(message) }
                    dismiss()
                }
            }
            .navigationDestination(for: String.self) { _ in AIPhotoSettingsView() }
            .onAppear {
                let nowHasKey = KeychainStore.has(.anthropicAPIKey)
                if nowHasKey && !hasKey { hasKey = true; runAI() }
            }
            .task {
                guesses = (try? await FoodRecognizer.classify(image)) ?? []
                classifying = false
                if hasKey && ai == .idle { runAI() }
            }
        }
    }

    // MARK: AI estimate

    @ViewBuilder
    private var aiSection: some View {
        if !hasKey {
            LTCard {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Get a better estimate with AI", systemImage: "sparkles").font(.headline).foregroundStyle(Theme.textPrimary)
                    Text("Add your own Anthropic API key and Claude will split the plate into foods and estimate how many grams of each you have. Calories still come from USDA data.")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    NavigationLink("Set up AI Photo Estimates", value: "ai-settings")
                        .font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("photo.setupAI")
                }
            }
        } else {
            switch ai {
            case .idle, .running:
                LTCard {
                    HStack(spacing: 12) {
                        ProgressView()
                        VStack(alignment: .leading) {
                            Text("Claude is estimating your portions…").foregroundStyle(Theme.textPrimary)
                            Text("Usually 5–30 seconds.").font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            case .failed(let message):
                NoteCard(text: message, warning: true)
                Button("Try Again") { runAI() }.buttonStyle(LTSecondaryButtonStyle())
            case .done:
                aiResults
            }
        }
    }

    @ViewBuilder
    private var aiResults: some View {
        if items.isEmpty {
            NoteCard(text: notes.isEmpty ? "Claude didn't find any food in this photo." : notes)
        } else {
            let included = items.filter { $0.include && $0.food != nil }
            let total = NutritionMath.sum(included.compactMap(\.nutrients))
            HStack {
                Label("AI estimate", systemImage: "sparkles").font(.headline).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(Format.calories(total.kcal ?? 0)) cal").font(.headline).foregroundStyle(Theme.textPrimary)
                    .accessibilityIdentifier("photo.totalCalories")
            }
            ForEach($items) { $item in AIItemCard(item: $item) }
            if !notes.isEmpty { Text(notes).font(.caption).foregroundStyle(Theme.textSecondary) }
            Text("Portion sizes are AI estimates from the photo, so they can be off, especially for oil, sauces and food you can't see. Adjust the grams if you know better. Calories and nutrients come from USDA FoodData Central.")
                .font(.caption).foregroundStyle(Theme.textSecondary)
            Button("Add \(included.count) food\(included.count == 1 ? "" : "s") to \(meal.title)") { addAI(included) }
                .buttonStyle(LTPrimaryButtonStyle())
                .disabled(included.isEmpty)
                .accessibilityIdentifier("photo.addAll")
        }
    }

    private func runAI() {
        ai = .running
        Task {
            do {
                let estimate = try await ClaudeFoodEstimator.estimate(image: image)
                items = estimate.items.map { item in
                    AIItem(name: item.name, grams: max(1, item.grams.rounded()), confidence: item.confidence, matches: matches(for: item))
                }
                notes = estimate.notes
                ai = .done
            } catch {
                ai = .failed(error.localizedDescription)
            }
        }
    }

    private func matches(for item: ClaudeFoodEstimator.Item) -> [Food] {
        guard let db = FoodDatabase.shared else { return [] }
        var found = db.search(item.search_terms, limit: 6)
        if found.isEmpty { found = db.search(item.name, limit: 6) }
        return found.compactMap { db.food(id: $0.id) }
    }

    private func addAI(_ included: [AIItem]) {
        let portions: [FoodPortion] = included.compactMap { item in
            guard let food = item.food else { return nil }
            var logged = LoggedFood.fromUSDA(food)
            if let common = FoodDatabase.shared?.commonEntry(foodID: food.id) { logged.name = common.name }
            return FoodPortion(food: logged, amount: item.grams, unit: .gram)
        }
        DiaryService.add(portions, meal: meal, day: day, in: context)
        onLogged("Added \(portions.count) food\(portions.count == 1 ? "" : "s") to \(meal.title)")
        dismiss()
    }

    // MARK: On-device

    @ViewBuilder
    private var onDeviceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            LTSectionHeader(title: hasKey ? "On-device guesses" : "What it looks like", trailing: "On this iPhone")
            if classifying {
                ProgressView().frame(maxWidth: .infinity)
            } else if guesses.isEmpty {
                LTCard {
                    Text("The on-device check didn't recognize a food. Go back and search for it, or scan its barcode.")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                }
            } else {
                ForEach(guesses) { guess in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(guess.label.capitalized) · \(Int((guess.confidence * 100).rounded()))% sure")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                        LTCardList(items: guess.matches.compactMap { s in FoodDatabase.shared?.food(id: s.id).map { FoodPortion.defaultFor($0) } }) { portion in
                            FoodRow(portion: portion).onTapGesture { path.append(portion) }
                        }
                    }
                }
                Text("Pick the closest match, then set the amount. A photo can't measure portion size on its own.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

/// One food from the AI estimate: include toggle, USDA match, grams.
private struct AIItemCard: View {
    @Binding var item: PhotoFoodView.AIItem

    var body: some View {
        LTCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Toggle(isOn: $item.include) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name.capitalized).font(.headline).foregroundStyle(Theme.textPrimary)
                            Text("\(item.confidence.capitalized) confidence").font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                if item.matches.isEmpty {
                    Text("No matching USDA food found. Add it from search instead.").font(.caption).foregroundStyle(Theme.fat)
                } else {
                    Menu {
                        Picker("USDA food", selection: $item.selected) {
                            ForEach(Array(item.matches.enumerated()), id: \.offset) { index, food in
                                Text(food.name).tag(index)
                            }
                        }
                    } label: {
                        HStack {
                            Text(item.food?.name ?? "Choose").foregroundStyle(Theme.accent).lineLimit(2).multilineTextAlignment(.leading)
                            Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    HStack {
                        Stepper(value: $item.grams, in: 1...2000, step: item.grams < 50 ? 5 : 10) {
                            Text("\(Format.number(item.grams)) g").foregroundStyle(Theme.textPrimary).monospacedDigit()
                        }
                    }
                    if let n = item.nutrients {
                        Text(Format.macroLine(n)).font(.footnote).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .opacity(item.include ? 1 : 0.5)
    }
}

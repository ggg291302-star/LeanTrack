import SwiftUI
import SwiftData

/// More → Goals (also Settings → Nutrition Goals).
struct GoalsView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        Group {
            if let profile = profiles.first {
                GoalsContent(profile: profile)
            }
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct GoalsContent: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var context
    @State private var addingGoal = false

    var body: some View {
        let macros = profile.macroGoals
        List {
            Section {
                NavigationLink { CalorieGoalView(profile: profile) } label: {
                    HStack {
                        Text("Calorie Goal").foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(profile.calorieGoal.formatted()) calories").foregroundStyle(Theme.textSecondary)
                    }
                }
                .accessibilityIdentifier("goals.calories")
            }
            .listRowBackground(Theme.card)

            Section {
                NavigationLink { MacroGoalsView(profile: profile) } label: {
                    VStack(spacing: 12) {
                        macroRow("Protein", macros.protein, profile.proteinPercent, Theme.protein)
                        macroRow("Carbs", macros.carbs, profile.carbsPercent, Theme.carbs)
                        macroRow("Fats", macros.fat, profile.fatPercent, Theme.fat)
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityIdentifier("goals.macros")
            } header: {
                Text("Macro Goals · \(profile.macroPreset.title)")
            }
            .listRowBackground(Theme.card)

            Section("Additional Goals") {
                HStack {
                    Label("Fiber", systemImage: "leaf")
                    Spacer()
                    Stepper("\(Format.number(profile.fiberGoalG)) g", value: $profile.fiberGoalG, in: 5...80, step: 1).fixedSize()
                }
                HStack {
                    Label("Water", systemImage: "drop")
                    Spacer()
                    Stepper(Format.volume(ml: profile.waterGoalMl, unit: profile.volumeUnit), value: $profile.waterGoalMl, in: 500...6000,
                            step: profile.volumeUnit == .milliliters ? 100 : UnitConversion.milliliters(fromFluidOunces: 4)).fixedSize()
                }
                ForEach(profile.extraGoals.keys.sorted(), id: \.self) { key in
                    if let info = NutrientInfo.info(for: key) {
                        HStack {
                            Text(info.name)
                            Spacer()
                            Stepper("\(info.format(profile.extraGoals[key]))", value: Binding(
                                get: { profile.extraGoals[key] ?? 0 },
                                set: { profile.extraGoals[key] = max(0, $0) }
                            ), step: stepFor(info)).fixedSize()
                        }
                    }
                }
                .onDelete { offsets in
                    let keys = profile.extraGoals.keys.sorted()
                    var goals = profile.extraGoals
                    for i in offsets { goals[keys[i]] = nil }
                    profile.extraGoals = goals
                }
                Button { addingGoal = true } label: { Label("Add Goal", systemImage: "plus") }
                    .accessibilityIdentifier("goals.add")
            }
            .listRowBackground(Theme.card)

            Section {
                Text("Fiber: 14 g per 1,000 calories (Dietary Guidelines for Americans). Water: about 2.2 L (women) or 3.0 L (men) of total beverages a day (National Academies). Extra goals start at the FDA Daily Value; sodium, sugar, saturated fat, cholesterol and caffeine are limits to stay under.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .onChange(of: profile.fiberGoalG) { try? context.save() }
        .onChange(of: profile.waterGoalMl) { try? context.save() }
        .sheet(isPresented: $addingGoal) {
            AddNutrientGoalSheet(existing: Set(profile.extraGoals.keys)) { key, amount in
                var goals = profile.extraGoals
                goals[key] = amount
                profile.extraGoals = goals
                try? context.save()
            }
        }
    }

    private func stepFor(_ info: NutrientInfo) -> Double {
        switch info.unit {
        case "mg": return (info.dailyValue ?? 100) >= 1000 ? 100 : ((info.dailyValue ?? 10) >= 100 ? 10 : 1)
        case "µg": return 1
        default: return 1
        }
    }

    private func macroRow(_ name: String, _ grams: Double, _ percent: Double, _ color: Color) -> some View {
        HStack {
            MacroDot(color: color, size: 14)
            Text(name).foregroundStyle(Theme.textPrimary)
            Spacer()
            Text("\(Format.number(grams)) g").foregroundStyle(Theme.textPrimary).monospacedDigit().frame(width: 70, alignment: .trailing)
            Text("\(Format.number(percent))%").foregroundStyle(Theme.textSecondary).monospacedDigit().frame(width: 50, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Pick a nutrient for an extra daily goal (starts at the FDA Daily Value).
private struct AddNutrientGoalSheet: View {
    let existing: Set<String>
    let onAdd: (String, Double) -> Void
    @Environment(\.dismiss) private var dismiss

    private static let limits: Set<String> = ["sodium", "sugar", "sat_fat", "cholesterol", "caffeine"]

    var body: some View {
        NavigationStack {
            List {
                ForEach(NutrientInfo.goalCandidates.filter { !existing.contains($0) }, id: \.self) { key in
                    if let info = NutrientInfo.info(for: key) {
                        let start = startValue(info)
                        Button {
                            onAdd(key, start)
                            dismiss()
                        } label: {
                            HStack {
                                Text(Self.limits.contains(key) ? "\(info.name) (limit)" : info.name).foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text(info.format(start)).foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    /// FDA Daily Value; sugar uses the added-sugars DV (50 g); caffeine uses the FDA's 400 mg/day guidance for healthy adults.
    private func startValue(_ info: NutrientInfo) -> Double {
        switch info.key {
        case "sugar": 50
        case "caffeine": 400
        default: info.dailyValue ?? 0
        }
    }
}

// MARK: - Calorie goal

/// Weight goal, pace and activity → suggested calories (with guardrails), or the owner's own number.
struct CalorieGoalView: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var context

    var body: some View {
        let plan = profile.recommendedPlan
        Form {
            Section("Weight goal") {
                Picker("Goal", selection: Binding(get: { profile.goal }, set: { profile.goal = $0; resetPace(); update() })) {
                    ForEach(WeightGoal.allCases) { Text($0.title).tag($0) }
                }
                if profile.goal != .maintain {
                    WeightField(title: "Goal weight", kg: Binding(get: { profile.goalWeightKg }, set: { profile.goalWeightKg = $0; update() }), unit: profile.weightUnit)
                    Picker("Pace", selection: Binding(get: { profile.paceLbPerWeek }, set: { profile.paceLbPerWeek = $0; update() })) {
                        ForEach(paces, id: \.self) { Text(paceLabel($0)).tag($0) }
                    }
                }
                Picker("Activity", selection: Binding(get: { profile.activity }, set: { profile.activity = $0; update() })) {
                    ForEach(ActivityLevel.allCases) { Text($0.title).tag($0) }
                }
                if profile.sex == .female {
                    Toggle("Pregnant or breastfeeding", isOn: Binding(get: { profile.pregnantOrBreastfeeding }, set: { profile.pregnantOrBreastfeeding = $0; update() }))
                }
            }

            Section("Suggested") {
                LabeledContent("Resting burn (BMR)", value: "\(Format.calories(plan.bmr)) cal")
                LabeledContent("× activity \(Format.number(profile.activity.multiplier, decimals: 3))", value: "\(Format.calories(plan.tdee)) cal")
                if profile.goal != .maintain && plan.paceLbPerWeek > 0 {
                    LabeledContent("\(profile.goal == .lose ? "−" : "+") \(Format.number(plan.paceLbPerWeek, decimals: 2)) lb/week × 3,500 ÷ 7",
                                   value: "\(Format.calories(plan.paceLbPerWeek * EnergyMath.kcalPerPound / 7)) cal")
                }
                LabeledContent("Suggested goal", value: "\(plan.calories.formatted()) cal")
                    .font(.headline)
                ForEach(Array(plan.notes.enumerated()), id: \.offset) { _, note in
                    Label(note.text, systemImage: note.isWarning ? "exclamationmark.triangle.fill" : "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(note.isWarning ? Theme.fat : Theme.textSecondary)
                }
            }

            Section {
                Toggle("Set my own calorie goal", isOn: Binding(get: { profile.calorieGoalIsManual }, set: {
                    profile.calorieGoalIsManual = $0
                    if !$0 { profile.calorieGoal = plan.calories }
                    update()
                }))
                .accessibilityIdentifier("calorieGoal.manual")
                if profile.calorieGoalIsManual {
                    Stepper("\(profile.calorieGoal.formatted()) calories", value: Binding(get: { profile.calorieGoal }, set: { profile.calorieGoal = $0; update() }),
                            in: 800...6000, step: 50)
                    ForEach(EnergyMath.manualGoalWarnings(calories: profile.calorieGoal, sex: profile.sex), id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle.fill").font(.subheadline).foregroundStyle(Theme.fat)
                    }
                } else {
                    LabeledContent("Daily goal", value: "\(profile.calorieGoal.formatted()) calories")
                }
            } footer: {
                Text("These are estimates; real needs vary by a few hundred calories. Watch your weight trend for 2–3 weeks and adjust. LeanTrack gives general information, not medical advice. Talk to a doctor before big diet changes, especially with a health condition.")
            }

            Section {
                Toggle("Add exercise calories back", isOn: $profile.exerciseAddsBack)
            } footer: {
                Text("Off by default: activity level already counts your usual exercise, and exercise calorie estimates often run high.")
            }
        }
        .navigationTitle("Calorie Goal")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: profile.exerciseAddsBack) { try? context.save() }
    }

    private var paces: [Double] {
        let options = profile.goal == .lose ? [0.5, 1, 1.5, 2] : [0.25, 0.5]
        return options.contains(profile.paceLbPerWeek) ? options : (options + [profile.paceLbPerWeek]).sorted()
    }

    private func paceLabel(_ lb: Double) -> String {
        profile.weightUnit == .kg
            ? "\(Format.number(UnitConversion.kilograms(fromPounds: lb), decimals: 2)) kg / week"
            : "\(Format.number(lb, decimals: 2)) lb / week"
    }

    private func resetPace() {
        profile.paceLbPerWeek = profile.goal == .lose ? 1 : profile.goal == .gain ? 0.5 : 0
        if profile.goal == .maintain { profile.goalWeightKg = profile.currentWeightKg }
    }

    private func update() {
        profile.applyRecommendedCalories()
        try? context.save()
    }
}

// MARK: - Macros

/// Macro split as presets or custom. Percents always add up to 100; grams follow the calorie goal.
struct MacroGoalsView: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var context

    var body: some View {
        let grams = profile.macroGoals
        Form {
            Section("Preset") {
                Picker("Split", selection: Binding(get: { profile.macroPreset }, set: { preset in
                    profile.macroPreset = preset
                    profile.applyMacroPreset()
                    try? context.save()
                })) {
                    ForEach(MacroPreset.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("macros.preset")
            }
            Section {
                macroEditor("Protein", \.proteinPercent, grams.protein, 4, Theme.protein, absorbs: \.carbsPercent)
                macroEditor("Carbs", \.carbsPercent, grams.carbs, 4, Theme.carbs, absorbs: \.fatPercent)
                macroEditor("Fat", \.fatPercent, grams.fat, 9, Theme.fat, absorbs: \.carbsPercent)
                LabeledContent("Total", value: "\(Format.number(profile.proteinPercent + profile.carbsPercent + profile.fatPercent))%")
                    .accessibilityIdentifier("macros.total")
            } header: {
                Text("\(profile.calorieGoal.formatted()) calories a day")
            } footer: {
                Text("Change a percent or the grams; the other macro adjusts so the total stays 100%. Protein and carbs have 4 calories per gram, fat has 9.")
            }
            Section {
                Text("Presets set protein from your weight: Balanced and Low Carb use 1.6 g per kg (\(Format.number(profile.currentWeightKg * 1.6)) g for you), the amount shown to help keep muscle while losing weight; High Protein uses 2.0 g per kg (\(Format.number(profile.currentWeightKg * 2)) g). Protein updates when you log a new weight. The bare minimum (RDA) is 0.8 g per kg.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .navigationTitle("Macro Goals")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func macroEditor(_ name: String, _ path: ReferenceWritableKeyPath<UserProfile, Double>, _ grams: Double, _ kcalPerGram: Double,
                             _ color: Color, absorbs other: ReferenceWritableKeyPath<UserProfile, Double>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                MacroDot(color: color, size: 12)
                Text(name).font(.headline)
                Spacer()
                Stepper("\(Format.number(profile[keyPath: path]))%", value: Binding(
                    get: { profile[keyPath: path] },
                    set: { setPercent(path, to: $0, absorbedBy: other) }
                ), in: 0...100, step: 1)
                .fixedSize()
                .accessibilityIdentifier("macros.\(name.lowercased()).percent")
            }
            HStack {
                Text("Grams").foregroundStyle(Theme.textSecondary)
                Spacer()
                NumberField(placeholder: "g", value: Binding(
                    get: { grams.rounded() },
                    set: { g in
                        guard profile.calorieGoal > 0 else { return }
                        setPercent(path, to: (g * kcalPerGram / Double(profile.calorieGoal) * 100).rounded(), absorbedBy: other)
                    }
                ), unit: "g", decimals: 0)
            }
        }
        .padding(.vertical, 4)
    }

    /// Sets one macro's percent and moves the difference to another, keeping all three 0–100 and the sum at 100.
    private func setPercent(_ path: ReferenceWritableKeyPath<UserProfile, Double>, to value: Double, absorbedBy other: ReferenceWritableKeyPath<UserProfile, Double>) {
        let all: [ReferenceWritableKeyPath<UserProfile, Double>] = [\.proteinPercent, \.carbsPercent, \.fatPercent]
        let third = all.first { $0 != path && $0 != other } ?? other
        let maxValue = 100 - profile[keyPath: third]
        let newValue = min(max(0, value), 100)
        if newValue <= maxValue {
            profile[keyPath: path] = newValue
            profile[keyPath: other] = maxValue - newValue
        } else {
            profile[keyPath: path] = newValue
            profile[keyPath: other] = 0
            profile[keyPath: third] = 100 - newValue
        }
        profile.macroPreset = .custom
        try? context.save()
    }
}

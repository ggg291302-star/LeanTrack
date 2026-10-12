import SwiftUI
import SwiftData

/// First-launch setup. Nothing is saved until "Start tracking" is tapped.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var step = 0
    @State private var draft = ProfileDraft()

    private let stepCount = 5

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if step > 0 {
                    ProgressView(value: Double(step), total: Double(stepCount - 1))
                        .tint(Theme.accent)
                        .padding(.horizontal, Theme.screenPadding)
                        .padding(.top, 8)
                        .accessibilityLabel("Step \(step) of \(stepCount - 1)")
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch step {
                        case 0: WelcomeStep()
                        case 1: AboutYouStep(draft: $draft)
                        case 2: GoalStep(draft: $draft)
                        case 3: ActivityStep(draft: $draft)
                        default: PlanStep(draft: $draft)
                        }
                    }
                    .padding(Theme.screenPadding)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                bottomButtons
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("Back") { step -= 1 }
                    .buttonStyle(LTSecondaryButtonStyle())
                    .accessibilityIdentifier("onboarding.back")
            }
            Button(step == stepCount - 1 ? "Start tracking" : "Continue") {
                if step == stepCount - 1 { finish() } else { step += 1 }
            }
            .buttonStyle(LTPrimaryButtonStyle())
            .disabled(!canContinue)
            .accessibilityIdentifier("onboarding.continue")
        }
        .padding(Theme.screenPadding)
        .background(Theme.background)
    }

    private var canContinue: Bool {
        switch step {
        case 1: draft.heightCm >= 90 && draft.heightCm <= 250 && draft.weightKg >= 25 && draft.weightKg <= 350
        case 2: draft.goal == .maintain || (draft.goalWeightKg >= 25 && draft.goalWeightKg <= 350)
        default: true
        }
    }

    private func finish() {
        let profile = UserProfile()
        draft.apply(to: profile)
        profile.setupComplete = true
        context.insert(profile)
        context.insert(WeightEntry(date: .now, weightKg: draft.weightKg, note: "Starting weight"))
        try? context.save()
    }
}

/// Values typed during setup, in metric. Converted for display in the chosen units.
struct ProfileDraft {
    var name = ""
    var sex: Sex = .female
    var birthDate = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    var heightCm = 165.0
    var weightKg = 75.0
    var goalWeightKg = 68.0
    var goal: WeightGoal = .lose
    var paceLbPerWeek = 1.0
    var activity: ActivityLevel = .light
    var pregnantOrBreastfeeding = false
    var weightUnit: WeightUnit = Locale.current.measurementSystem == .metric ? .kg : .lb
    var heightUnit: HeightUnit = Locale.current.measurementSystem == .metric ? .cm : .feetInches
    var macroPreset: MacroPreset = .balanced
    var manualCalories: Int? = nil

    var age: Int { Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 0 }

    var plan: EnergyMath.CaloriePlan {
        EnergyMath.plan(sex: sex, age: age, weightKg: weightKg, heightCm: heightCm, activity: activity, goal: goal,
                        paceLbPerWeek: paceLbPerWeek, goalWeightKg: goal == .maintain ? weightKg : goalWeightKg,
                        pregnantOrBreastfeeding: pregnantOrBreastfeeding)
    }

    var calorieGoal: Int { manualCalories ?? plan.calories }

    func apply(to p: UserProfile) {
        p.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        p.sex = sex
        p.birthDate = birthDate
        p.heightCm = heightCm
        p.currentWeightKg = weightKg
        p.startWeightKg = weightKg
        p.goal = plan.notes.contains(.noLossPlanUnder18) || plan.notes.contains(.noLossPlanPregnancy) ? .maintain : goal
        p.goalWeightKg = goal == .maintain ? weightKg : goalWeightKg
        p.paceLbPerWeek = plan.paceLbPerWeek
        p.activity = activity
        p.pregnantOrBreastfeeding = pregnantOrBreastfeeding
        p.calorieGoal = calorieGoal
        p.calorieGoalIsManual = manualCalories != nil
        p.macroPreset = macroPreset
        let percents = macroPreset.percents ?? (20, 50, 30)
        p.proteinPercent = percents.protein
        p.carbsPercent = percents.carbs
        p.fatPercent = percents.fat
        p.fiberGoalG = NutritionMath.fiberGoal(calories: calorieGoal)
        p.waterGoalMl = NutritionMath.defaultWaterGoalMl(sex: sex)
        p.weightUnit = weightUnit
        p.heightUnit = heightUnit
        p.foodUnit = weightUnit == .kg ? .grams : .ounces
        p.volumeUnit = weightUnit == .kg ? .milliliters : .fluidOunces
    }
}

// MARK: - Steps

private struct WelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.calorieRing)
                .padding(.top, 40)
                .accessibilityHidden(true)
            Text("Welcome to LeanTrack")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.textPrimary)
            Text("Track food, calories, macros, water, weight and BMI with real USDA nutrition data.")
                .font(.title3)
                .foregroundStyle(Theme.textSecondary)
            LTCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Everything stays on your phone. No account, no ads.", systemImage: "lock.fill")
                    Label("13,000+ foods work offline.", systemImage: "wifi.slash")
                    Label("A few questions give you a starting calorie goal. You can change it any time.", systemImage: "target")
                }
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
            }
        }
    }
}

private struct AboutYouStep: View {
    @Binding var draft: ProfileDraft

    var body: some View {
        StepHeader(title: "About you", subtitle: "Used for the calorie formulas. It stays on your phone.")
        LTCard {
            VStack(alignment: .leading, spacing: 16) {
                LabeledField("Name (optional)") {
                    TextField("Your name", text: $draft.name)
                        .textContentType(.givenName)
                        .multilineTextAlignment(.trailing)
                }
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sex").foregroundStyle(Theme.textPrimary)
                    Picker("Sex", selection: $draft.sex) {
                        ForEach(Sex.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text("The formulas (Mifflin-St Jeor) differ for female and male bodies.")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Divider()
                DatePicker("Birthday", selection: $draft.birthDate, in: ...Date.now, displayedComponents: .date)
                    .foregroundStyle(Theme.textPrimary)
                if draft.sex == .female {
                    Divider()
                    Toggle("Pregnant or breastfeeding", isOn: $draft.pregnantOrBreastfeeding)
                        .foregroundStyle(Theme.textPrimary)
                }
            }
        }
        LTCard {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Units", selection: $draft.weightUnit) {
                    Text("lb, ft/in").tag(WeightUnit.lb)
                    Text("kg, cm").tag(WeightUnit.kg)
                }
                .pickerStyle(.segmented)
                .onChange(of: draft.weightUnit) { _, unit in draft.heightUnit = unit == .kg ? .cm : .feetInches }
                HeightField(heightCm: $draft.heightCm, unit: draft.heightUnit)
                Divider()
                WeightField(title: "Current weight", kg: $draft.weightKg, unit: draft.weightUnit)
                    .accessibilityIdentifier("onboarding.weight")
            }
        }
    }
}

private struct GoalStep: View {
    @Binding var draft: ProfileDraft

    private var lossPaces: [Double] { [0.5, 1, 1.5, 2] }
    private var gainPaces: [Double] { [0.25, 0.5] }

    var body: some View {
        StepHeader(title: "Your goal", subtitle: "You can change this later in Goals.")
        Picker("Goal", selection: $draft.goal) {
            ForEach(WeightGoal.allCases) { Text($0.title.replacingOccurrences(of: " weight", with: "")).tag($0) }
        }
        .pickerStyle(.segmented)
        .onChange(of: draft.goal) { _, goal in
            draft.paceLbPerWeek = goal == .gain ? 0.5 : goal == .lose ? 1 : 0
            if goal == .maintain { draft.goalWeightKg = draft.weightKg }
        }

        if draft.goal != .maintain {
            LTCard {
                VStack(alignment: .leading, spacing: 16) {
                    WeightField(title: "Goal weight", kg: $draft.goalWeightKg, unit: draft.weightUnit)
                    Divider()
                    Text(draft.goal == .lose ? "How fast do you want to lose?" : "How fast do you want to gain?")
                        .foregroundStyle(Theme.textPrimary)
                    Picker("Pace", selection: $draft.paceLbPerWeek) {
                        ForEach(draft.goal == .lose ? lossPaces : gainPaces, id: \.self) { pace in
                            Text(paceLabel(pace)).tag(pace)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(draft.goal == .lose
                         ? "Losing about 0.5–2 lb (0.25–1 kg) a week is a common, sustainable range."
                         : "Gaining slowly (0.25–0.5 lb a week) keeps most of the gain as muscle when paired with strength training.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        if draft.age < 18 || draft.pregnantOrBreastfeeding, draft.goal == .lose {
            NoteCard(text: draft.age < 18 ? EnergyMath.Note.noLossPlanUnder18.text : EnergyMath.Note.noLossPlanPregnancy.text, warning: true)
        }
    }

    private func paceLabel(_ lb: Double) -> String {
        draft.weightUnit == .kg
            ? "\(Format.number(UnitConversion.kilograms(fromPounds: lb), decimals: 2)) kg"
            : "\(Format.number(lb, decimals: 2)) lb"
    }
}

private struct ActivityStep: View {
    @Binding var draft: ProfileDraft

    var body: some View {
        StepHeader(title: "Activity level", subtitle: "On a normal week, not counting the exercise you'll log.")
        VStack(spacing: 0) {
            ForEach(ActivityLevel.allCases) { level in
                Button {
                    draft.activity = level
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(level.title).foregroundStyle(Theme.textPrimary)
                            Text(level.explanation).font(.caption).foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        if draft.activity == level {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                        }
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(draft.activity == level ? [.isSelected] : [])
                if level != ActivityLevel.allCases.last { LTRowDivider(leadingInset: 16) }
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

private struct PlanStep: View {
    @Binding var draft: ProfileDraft
    @State private var editingGoal = false

    var body: some View {
        let plan = draft.plan
        StepHeader(title: "Your plan", subtitle: "A starting point you can adjust any time.")
        LTCard {
            VStack(spacing: 6) {
                Text(draft.calorieGoal.formatted())
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityIdentifier("onboarding.calories")
                Text("calories a day").foregroundStyle(Theme.textSecondary)
                if draft.manualCalories != nil {
                    Text("Set by you").font(.caption).foregroundStyle(Theme.accent)
                }
            }
            .frame(maxWidth: .infinity)
        }
        LTCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("How we got this").font(.headline).foregroundStyle(Theme.textPrimary)
                MathRow(label: "Resting burn (BMR, Mifflin-St Jeor)", value: "\(Format.calories(plan.bmr)) cal")
                MathRow(label: "× activity (\(Format.number(draft.activity.multiplier, decimals: 3)))", value: "\(Format.calories(plan.tdee)) cal")
                if plan.paceLbPerWeek > 0 && draft.goal != .maintain {
                    let daily = plan.paceLbPerWeek * EnergyMath.kcalPerPound / 7
                    MathRow(label: "\(draft.goal == .lose ? "−" : "+") \(Format.number(plan.paceLbPerWeek, decimals: 2)) lb/week × 3,500 ÷ 7", value: "\(Format.calories(daily)) cal")
                }
                Text("These are estimates. Real burn varies from person to person by a few hundred calories. Watch your weight trend and adjust.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        ForEach(Array(plan.notes.enumerated()), id: \.offset) { _, note in
            NoteCard(text: note.text, warning: note.isWarning)
        }
        if let manual = draft.manualCalories {
            ForEach(EnergyMath.manualGoalWarnings(calories: manual, sex: draft.sex), id: \.self) { NoteCard(text: $0, warning: true) }
        }
        LTCard {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Set my own calorie goal", isOn: Binding(
                    get: { draft.manualCalories != nil },
                    set: { draft.manualCalories = $0 ? plan.calories : nil }
                ))
                .foregroundStyle(Theme.textPrimary)
                if draft.manualCalories != nil {
                    Stepper(value: Binding(get: { draft.manualCalories ?? plan.calories }, set: { draft.manualCalories = $0 }),
                            in: 800...6000, step: 50) {
                        Text("\((draft.manualCalories ?? 0).formatted()) cal").foregroundStyle(Theme.textPrimary)
                    }
                }
            }
        }
        LTCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Macros").font(.headline).foregroundStyle(Theme.textPrimary)
                Picker("Macro preset", selection: $draft.macroPreset) {
                    ForEach(MacroPreset.allCases.filter { $0 != .custom }) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                let p = draft.macroPreset.percents ?? (20, 50, 30)
                let grams = MacroGrams.fromPercents(calories: Double(draft.calorieGoal), protein: p.protein, carbs: p.carbs, fat: p.fat)
                HStack {
                    MacroGoalPill(name: "Protein", grams: grams.protein, percent: p.protein, color: Theme.protein)
                    MacroGoalPill(name: "Carbs", grams: grams.carbs, percent: p.carbs, color: Theme.carbs)
                    MacroGoalPill(name: "Fat", grams: grams.fat, percent: p.fat, color: Theme.fat)
                }
                Text("Protein suggestion: at least \(Format.number(draft.weightKg * 0.8)) g a day (the RDA of 0.8 g per kg of body weight). Custom splits are in Goals.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        Text("LeanTrack gives general estimates, not medical advice. Talk to a doctor before big changes to your diet, especially if you have a health condition.")
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)
    }
}

// MARK: - Small pieces

private struct StepHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.largeTitle.bold()).foregroundStyle(Theme.textPrimary).accessibilityAddTraits(.isHeader)
            Text(subtitle).foregroundStyle(Theme.textSecondary)
        }
        .padding(.top, 8)
    }
}

private struct MathRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value).foregroundStyle(Theme.textPrimary).monospacedDigit()
        }
        .font(.subheadline)
    }
}

struct NoteCard: View {
    let text: String
    var warning = false
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: warning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundStyle(warning ? Theme.fat : Theme.accent)
                .accessibilityHidden(true)
            Text(text).font(.subheadline).foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct MacroGoalPill: View {
    let name: String
    let grams: Double
    let percent: Double
    let color: Color
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) { MacroDot(color: color, size: 8); Text(name).font(.caption).foregroundStyle(Theme.textSecondary) }
            Text("\(Format.number(grams)) g").font(.headline).foregroundStyle(Theme.textPrimary)
            Text("\(Format.number(percent))%").font(.caption).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.cardElevated, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Query private var profiles: [UserProfile]
    @State private var showingDatePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                    header
                    if let profile = profiles.first {
                        HomeDayContent(day: appState.selectedDay, profile: profile)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingDatePicker) { DayPickerSheet() }
        }
    }

    private var header: some View {
        HStack {
            Button {
                showingDatePicker = true
            } label: {
                HStack(spacing: 4) {
                    Text(Format.dayTitle(appState.selectedDay)).font(.title2.bold())
                    Image(systemName: "chevron.down").font(.footnote.weight(.bold))
                }
                .foregroundStyle(Theme.textPrimary)
            }
            .accessibilityLabel("\(Format.dayTitle(appState.selectedDay)). Change day")
            .accessibilityIdentifier("home.dayPicker")
            Spacer()
            StreakBadge()
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

/// Everything on Home for one day (re-created when the day changes so the queries follow it).
private struct HomeDayContent: View {
    let day: Date
    let profile: UserProfile
    @Environment(AppState.self) private var appState
    @Query private var entries: [DiaryEntry]
    @Query private var exercise: [ExerciseEntry]
    @State private var editing: DiaryEntry?

    init(day: Date, profile: UserProfile) {
        self.day = day
        self.profile = profile
        let start = Calendar.current.startOfDay(for: day)
        _entries = Query(filter: #Predicate<DiaryEntry> { $0.day == start }, sort: \.createdAt)
        _exercise = Query(filter: #Predicate<ExerciseEntry> { $0.day == start })
    }

    var body: some View {
        let totals = DiaryService.totals(entries)
        let goals = profile.macroGoals
        let shares = NutritionMath.macroShares(protein: totals.protein, carbs: totals.carbs, fat: totals.fat)
        let sharePercents = NutritionMath.roundedTo100([shares.protein, shares.carbs, shares.fat])

        CalorieRing(eaten: totals.kcal, goal: profile.calorieGoal)
            .frame(width: 200, height: 200)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

        HStack(spacing: 10) {
            MacroCard(name: "Protein", grams: totals.protein, goal: goals.protein, sharePercent: sharePercents[0], color: Theme.protein)
            MacroCard(name: "Carbs", grams: totals.carbs, goal: goals.carbs, sharePercent: sharePercents[1], color: Theme.carbs)
            MacroCard(name: "Fat", grams: totals.fat, goal: goals.fat, sharePercent: sharePercents[2], color: Theme.fat)
        }

        let burned = exercise.reduce(0) { $0 + $1.kcal }
        let remaining = NutritionMath.remaining(goal: profile.calorieGoal, eaten: totals.kcal, exercise: burned, addExercise: profile.exerciseAddsBack)
        LTCard {
            VStack(spacing: 6) {
                HStack {
                    Text("Remaining").foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(Format.calories(abs(remaining))) cal\(remaining < 0 ? " over" : "")")
                        .font(.headline)
                        .foregroundStyle(remaining < 0 ? Theme.fat : Theme.textPrimary)
                        .accessibilityIdentifier("home.remaining")
                }
                if burned > 0 {
                    HStack {
                        Text("Exercise").font(.caption).foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text("\(Format.calories(burned)) cal\(profile.exerciseAddsBack ? " added back" : " (not added back)")")
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(remaining < 0 ? "\(Format.calories(-remaining)) calories over goal" : "\(Format.calories(remaining)) calories remaining")

        HStack {
            Text(Calendar.current.isDateInToday(day) ? "Today's Meals" : "Meals").font(.title3.bold()).foregroundStyle(Theme.textPrimary)
            Spacer()
            Button {
                appState.selectedTab = .diary
            } label: {
                HStack(spacing: 2) { Text("View all"); Image(systemName: "chevron.right").font(.caption.weight(.semibold)) }
            }
            .accessibilityIdentifier("home.viewAll")
        }
        .padding(.top, 6)

        if entries.isEmpty {
            LTCard {
                VStack(spacing: 6) {
                    Text("Nothing logged yet").font(.headline).foregroundStyle(Theme.textPrimary)
                    Text("Tap the blue + to add food.").font(.subheadline).foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            VStack(spacing: 0) {
                let shown = Array(entries.suffix(6).reversed())
                ForEach(shown) { entry in
                    Button { editing = entry } label: { EntryRow(entry: entry) }
                        .buttonStyle(.plain)
                    if entry.id != shown.last?.id { LTRowDivider(leadingInset: 72) }
                }
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }

        WaterCard(day: day, profile: profile)
            .sheet(item: $editing) { entry in EntryEditorSheet(entry: entry) }
    }
}

/// One macro card: grams eaten (big), share of today's calories, and progress to the goal.
struct MacroCard: View {
    let name: String
    let grams: Double
    let goal: Double
    let sharePercent: Int
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text("\(Format.number(grams))g")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(name).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
            HStack(spacing: 4) {
                MacroDot(color: color, size: 8)
                Text("\(sharePercent)% of cal").font(.caption).foregroundStyle(Theme.textSecondary)
            }
            LTProgressBar(value: goal > 0 ? grams / goal : 0, color: color)
                .padding(.top, 2)
            Text("of \(Format.number(goal))g goal").font(.caption2).foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name): \(Format.number(grams)) grams eaten of \(Format.number(goal)) gram goal, \(sharePercent) percent of calories")
    }
}

/// A diary entry: icon, name and amount, "cal • P • C • F", chevron.
struct EntryRow: View {
    let entry: DiaryEntry

    var body: some View {
        let portion = entry.portion
        HStack(spacing: 12) {
            FoodIcon(group: portion.food.group, imageURL: portion.food.imageURL.flatMap { URL(string: $0) })
            VStack(alignment: .leading, spacing: 3) {
                Text("\(entry.name) (\(portion.amountText))")
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                Text("\(Format.calories(entry.kcal)) cal • \(Format.grams(entry.protein))g P • \(Format.grams(entry.carbs))g C • \(Format.grams(entry.fat))g F")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Edit amount")
    }
}

/// Streak flame (days logged in a row) in place of the design's crown.
struct StreakBadge: View {
    @Query(sort: \DiaryEntry.day, order: .reverse) private var entries: [DiaryEntry]

    var body: some View {
        let streak = DiaryService.streak(loggedDays: Set(entries.prefix(3000).map(\.day)))
        if streak > 0 {
            HStack(spacing: 4) {
                Text("🔥")
                Text("\(streak)").font(.headline).foregroundStyle(Theme.streak)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Theme.card, in: Capsule())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(streak) day logging streak")
        }
    }
}

/// "Today ▾" date picker.
struct DayPickerSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            DatePicker("Day", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle("Choose a day")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Today") { appState.select(day: .now); dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { appState.select(day: date); dismiss() }
                    }
                }
                .onAppear { date = appState.selectedDay }
        }
        .presentationDetents([.medium, .large])
    }
}

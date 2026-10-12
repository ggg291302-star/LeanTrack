import SwiftUI
import SwiftData

struct DiaryView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                LTScreenTitle(title: "Food Diary")
                WeekStrip()
                    .padding(.horizontal, Theme.screenPadding)
                DiaryDayList(day: appState.selectedDay)
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

/// Sun–Sat strip for the week of the selected day, with arrows for other weeks.
struct WeekStrip: View {
    @Environment(AppState.self) private var appState
    private let calendar = Calendar.current

    var body: some View {
        let days = weekDays(containing: appState.selectedDay)
        HStack(spacing: 2) {
            Button { shift(weeks: -1) } label: { Image(systemName: "chevron.left").frame(width: 24, height: 44) }
                .accessibilityLabel("Previous week")
            ForEach(days, id: \.self) { day in
                let selected = calendar.isDate(day, inSameDayAs: appState.selectedDay)
                Button { appState.select(day: day) } label: {
                    VStack(spacing: 2) {
                        Text(day.formatted(.dateTime.weekday(.abbreviated))).font(.caption)
                        Text(day.formatted(.dateTime.month(.abbreviated).day())).font(.caption2)
                    }
                    .foregroundStyle(selected ? Theme.accent : (calendar.isDateInToday(day) ? Theme.textPrimary : Theme.textSecondary))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(selected ? Theme.accent.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
            Button { shift(weeks: 1) } label: { Image(systemName: "chevron.right").frame(width: 24, height: 44) }
                .accessibilityLabel("Next week")
        }
        .padding(.bottom, 6)
    }

    private func weekDays(containing day: Date) -> [Date] {
        var cal = calendar
        cal.firstWeekday = 1 // Sunday, like the design
        let start = cal.dateInterval(of: .weekOfYear, for: day)?.start ?? day
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private func shift(weeks: Int) {
        if let d = calendar.date(byAdding: .day, value: 7 * weeks, to: appState.selectedDay) { appState.select(day: d) }
    }
}

/// The diary list for one day.
private struct DiaryDayList: View {
    let day: Date
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query private var entries: [DiaryEntry]
    @Query private var yesterdayEntries: [DiaryEntry]
    @Query private var exercise: [ExerciseEntry]
    @State private var editing: DiaryEntry?
    @State private var editingExercise: ExerciseEntry?
    @State private var addingExercise = false
    @State private var movingOrCopying: MoveCopyRequest?
    @State private var savingMeal: MealSlot?

    init(day: Date) {
        self.day = day
        let start = Calendar.current.startOfDay(for: day)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: start) ?? start
        _entries = Query(filter: #Predicate<DiaryEntry> { $0.day == start }, sort: \.createdAt)
        _yesterdayEntries = Query(filter: #Predicate<DiaryEntry> { $0.day == yesterday }, sort: \.createdAt)
        _exercise = Query(filter: #Predicate<ExerciseEntry> { $0.day == start }, sort: \.createdAt)
    }

    var body: some View {
        let totals = DiaryService.totals(entries)
        List {
            Section {
                HStack(spacing: 0) {
                    summaryColumn(Format.grams(totals.protein) + "g", "Protein")
                    Divider().frame(height: 34)
                    summaryColumn(Format.grams(totals.carbs) + "g", "Carbs")
                    Divider().frame(height: 34)
                    summaryColumn(Format.grams(totals.fat) + "g", "Fat")
                }
                .listRowBackground(Theme.card)
            } header: {
                HStack {
                    Text(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    Spacer()
                    Text("\(Format.calories(totals.kcal)) cal").accessibilityIdentifier("diary.dayTotal")
                }
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
                .textCase(nil)
            }

            ForEach(MealSlot.allCases) { meal in
                let items = entries.filter { $0.meal == meal }
                Section {
                    ForEach(items) { entry in
                        Button { editing = entry } label: { EntryRow(entry: entry).padding(.horizontal, -14) }
                            .buttonStyle(.plain)
                            .listRowBackground(Theme.card)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { DiaryService.delete(entry, in: context) } label: { Label("Delete", systemImage: "trash") }
                            }
                            .contextMenu {
                                Button { movingOrCopying = MoveCopyRequest(entries: [entry], copy: false) } label: { Label("Move to…", systemImage: "arrow.right.square") }
                                Button { movingOrCopying = MoveCopyRequest(entries: [entry], copy: true) } label: { Label("Copy to…", systemImage: "doc.on.doc") }
                                Button(role: .destructive) { DiaryService.delete(entry, in: context) } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                    Button {
                        appState.addFoodMeal = meal
                    } label: {
                        Label("Add Food", systemImage: "plus").foregroundStyle(Theme.accent)
                    }
                    .listRowBackground(Theme.card)
                    .accessibilityIdentifier("diary.add.\(meal.rawValue)")
                } header: {
                    mealHeader(meal: meal, items: items)
                }
            }

            Section {
                ForEach(exercise) { item in
                    Button { editingExercise = item } label: {
                        HStack {
                            Image(systemName: "figure.run").foregroundStyle(Theme.protein).frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).foregroundStyle(Theme.textPrimary)
                                Text("\(Format.number(item.minutes)) min").font(.footnote).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            Text("−\(Format.calories(item.kcal)) cal").foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Theme.card)
                }
                .onDelete { offsets in
                    for i in offsets { context.delete(exercise[i]) }
                    try? context.save()
                }
                Button { addingExercise = true } label: {
                    Label("Add Exercise", systemImage: "plus").foregroundStyle(Theme.accent)
                }
                .listRowBackground(Theme.card)
                .accessibilityIdentifier("diary.add.exercise")
            } header: {
                HStack {
                    Text("Exercise").font(.headline).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(Format.calories(exercise.reduce(0) { $0 + $1.kcal })) cal").font(.headline).foregroundStyle(Theme.textPrimary)
                }
                .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .sheet(item: $editing) { EntryEditorSheet(entry: $0) }
        .sheet(item: $editingExercise) { ExerciseSheet(entry: $0, day: day) }
        .sheet(isPresented: $addingExercise) { ExerciseSheet(entry: nil, day: day) }
        .sheet(item: $movingOrCopying) { MoveCopySheet(request: $0, fromDay: day) }
        .sheet(item: $savingMeal) { meal in
            SaveMealSheet(items: entries.filter { $0.meal == meal }.map(\.portion), suggestedName: meal.title)
        }
    }

    private func summaryColumn(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).foregroundStyle(Theme.textPrimary)
            Text(label).font(.caption).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func mealHeader(meal: MealSlot, items: [DiaryEntry]) -> some View {
        let yesterday = yesterdayEntries.filter { $0.meal == meal }
        return HStack {
            Text(meal.title).font(.headline).foregroundStyle(Theme.textPrimary)
            Spacer()
            Text("\(Format.calories(items.reduce(0) { $0 + $1.kcal })) cal").font(.headline).foregroundStyle(Theme.textPrimary)
            Menu {
                Button { DiaryService.copy(yesterday, to: meal, day: day, in: context) } label: {
                    Label("Copy from yesterday", systemImage: "arrow.uturn.down")
                }
                .disabled(yesterday.isEmpty)
                Button { savingMeal = meal } label: { Label("Save as meal", systemImage: "square.and.arrow.down") }
                    .disabled(items.isEmpty)
                Button { movingOrCopying = MoveCopyRequest(entries: items, copy: true) } label: { Label("Copy meal to…", systemImage: "doc.on.doc") }
                    .disabled(items.isEmpty)
            } label: {
                Image(systemName: "ellipsis.circle").font(.body).foregroundStyle(Theme.accent).frame(width: 32, height: 32)
            }
            .accessibilityLabel("\(meal.title) options")
            .accessibilityIdentifier("diary.menu.\(meal.rawValue)")
        }
        .textCase(nil)
    }
}

struct MoveCopyRequest: Identifiable {
    let id = UUID()
    let entries: [DiaryEntry]
    let copy: Bool
}

/// Choose a meal and day to move or copy entries to.
struct MoveCopySheet: View {
    let request: MoveCopyRequest
    let fromDay: Date
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var meal: MealSlot = .breakfast
    @State private var day = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") { MealPicker(meal: $meal) }
                Section("Day") { DatePicker("Day", selection: $day, displayedComponents: .date).datePickerStyle(.graphical) }
            }
            .navigationTitle(request.copy ? "Copy to…" : "Move to…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(request.copy ? "Copy" : "Move") {
                        if request.copy {
                            DiaryService.copy(request.entries, to: meal, day: day, in: context)
                        } else {
                            for e in request.entries { DiaryService.move(e, to: meal, day: day, in: context) }
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                day = fromDay
                meal = request.entries.first?.meal ?? .breakfast
            }
        }
    }
}

/// Save several diary items as a reusable meal.
struct SaveMealSheet: View {
    let items: [FoodPortion]
    let suggestedName: String
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Chicken, Rice & Broccoli", text: $name)
                        .accessibilityIdentifier("saveMeal.name")
                }
                Section("\(items.count) items") {
                    ForEach(items) { item in
                        HStack {
                            Text(item.food.name)
                            Spacer()
                            Text(item.amountText).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
            .navigationTitle("Save as Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        context.insert(SavedMeal(name: name.trimmingCharacters(in: .whitespaces), items: items))
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { if name.isEmpty { name = items.map(\.food.name).prefix(3).joined(separator: ", ") } }
        }
    }
}

import SwiftUI
import SwiftData

/// More → Weigh-ins: every weigh-in, newest first, with the change from the one before.
struct WeighInsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WeightEntry.date, order: .reverse) private var entries: [WeightEntry]
    @Query private var profiles: [UserProfile]
    @State private var adding = false
    @State private var editing: WeightEntry?

    var body: some View {
        let unit = profiles.first?.weightUnit ?? .lb
        List {
            if entries.isEmpty {
                Text("No weigh-ins yet. Tap + to log your weight.").foregroundStyle(Theme.textSecondary)
                    .listRowBackground(Theme.card)
            }
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                Button { editing = entry } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.date.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(Theme.textPrimary)
                            if !entry.note.isEmpty { Text(entry.note).font(.caption).foregroundStyle(Theme.textSecondary) }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Format.weight(kg: entry.weightKg, unit: unit)).font(.headline).foregroundStyle(Theme.textPrimary)
                            if index + 1 < entries.count {
                                let diffKg = entry.weightKg - entries[index + 1].weightKg
                                let diff = unit == .kg ? diffKg : UnitConversion.pounds(fromKilograms: diffKg)
                                Text("\(diff > 0 ? "+" : "")\(Format.number(diff, decimals: 1)) \(unit.rawValue)")
                                    .font(.caption).foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                }
                .listRowBackground(Theme.card)
            }
            .onDelete { offsets in
                for i in offsets { WeightService.delete(entries[i], profile: profiles.first, in: context) }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Weigh-ins")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { adding = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Log weight")
                    .accessibilityIdentifier("weighIns.add")
            }
        }
        .sheet(isPresented: $adding) { AddWeighInSheet(entry: nil) }
        .sheet(item: $editing) { AddWeighInSheet(entry: $0) }
    }
}

/// Log or edit a weigh-in (date, time, weight, note). Afterwards, offers to update the
/// calorie goal when the weight change moves the estimate.
struct AddWeighInSheet: View {
    let entry: WeightEntry?
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @State private var date = Date.now
    @State private var weightKg = 70.0
    @State private var note = ""
    @State private var loaded = false
    @State private var suggestion: Int?

    init(entry: WeightEntry?) {
        self.entry = entry
    }

    var body: some View {
        let unit = profiles.first?.weightUnit ?? .lb
        NavigationStack {
            Form {
                Section {
                    WeightField(title: "Weight", kg: $weightKg, unit: unit)
                        .accessibilityIdentifier("weighIn.weight")
                    DatePicker("Date & time", selection: $date, in: ...Date.now)
                    TextField("Note (optional)", text: $note)
                } footer: {
                    Text("Tip: weigh yourself at the same time each day, like after waking up. Day-to-day changes are mostly water; the 7-day trend on Progress shows the real direction.")
                }
                if let entry {
                    Section {
                        Button("Delete Weigh-in", role: .destructive) {
                            WeightService.delete(entry, profile: profiles.first, in: context)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(entry == nil ? "Log Weight" : "Edit Weigh-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(weightKg < 20 || weightKg > 400)
                        .accessibilityIdentifier("weighIn.save")
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let entry {
                    date = entry.date; weightKg = entry.weightKg; note = entry.note
                } else if let p = profiles.first {
                    weightKg = p.currentWeightKg
                }
            }
            .alert("Update your calorie goal?", isPresented: Binding(get: { suggestion != nil }, set: { if !$0 { suggestion = nil } })) {
                Button("Update") {
                    if let s = suggestion, let p = profiles.first {
                        p.calorieGoal = s
                        p.fiberGoalG = NutritionMath.fiberGoal(calories: s)
                        try? context.save()
                    }
                    suggestion = nil
                    dismiss()
                }
                Button("Not Now", role: .cancel) { suggestion = nil; dismiss() }
            } message: {
                if let s = suggestion, let p = profiles.first {
                    Text("Your weight changed, so your estimated needs changed too. Change your daily goal from \(p.calorieGoal.formatted()) to \(s.formatted()) calories?")
                }
            }
        }
    }

    private func save() {
        let profile = profiles.first
        if let entry {
            entry.date = date
            entry.weightKg = weightKg
            entry.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            try? context.save()
            if let profile { WeightService.syncCurrentWeight(profile: profile, in: context) }
        } else {
            WeightService.add(weightKg: weightKg, date: date, note: note, profile: profile, in: context)
        }
        if let profile, let s = WeightService.suggestedCalorieUpdate(profile: profile) {
            suggestion = s
        } else {
            dismiss()
        }
    }
}

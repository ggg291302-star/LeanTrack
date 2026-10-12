import SwiftUI

/// Amount + unit, using the food's real USDA portions (plus g and oz).
struct ServingPicker: View {
    @Binding var amount: Double
    @Binding var unit: ServingUnit
    let units: [ServingUnit]

    var body: some View {
        HStack(spacing: 10) {
            TextField("Amount", value: $amount, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.title3.weight(.semibold))
                .frame(width: 80, height: 44)
                .background(Theme.cardElevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityLabel("Amount")
                .accessibilityIdentifier("serving.amount")
            Menu {
                Picker("Unit", selection: $unit) {
                    ForEach(units) { u in
                        Text(label(for: u)).tag(u)
                    }
                }
            } label: {
                HStack {
                    Text(label(for: unit))
                        .lineLimit(1)
                        .foregroundStyle(Theme.textPrimary)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Theme.cardElevated, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .accessibilityLabel("Unit: \(label(for: unit))")
            .accessibilityIdentifier("serving.unit")
        }
    }

    private func label(for unit: ServingUnit) -> String {
        guard let grams = unit.grams, !["g", "ml", "fl oz"].contains(unit.name) else { return unit.name }
        return "\(unit.name) (\(Format.number(grams, decimals: grams < 10 ? 1 : 0)) g)"
    }
}

/// Meal picker shown as a segmented control.
struct MealPicker: View {
    @Binding var meal: MealSlot
    var body: some View {
        Picker("Meal", selection: $meal) {
            ForEach(MealSlot.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("mealPicker")
    }
}

/// Nutrient summary for an amount: big calories + donut + legend.
struct NutritionSummary: View {
    let nutrients: Nutrients

    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                MacroDonut(protein: nutrients.protein ?? 0, carbs: nutrients.carbs ?? 0, fat: nutrients.fat ?? 0)
                VStack(spacing: 0) {
                    Text(Format.calories(nutrients.kcal)).font(.title2.bold()).foregroundStyle(Theme.textPrimary)
                    Text("cal").font(.caption).foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: 110, height: 110)
            VStack(alignment: .leading, spacing: 10) {
                legend("Protein", nutrients.protein, Theme.protein)
                legend("Carbs", nutrients.carbs, Theme.carbs)
                legend("Fat", nutrients.fat, Theme.fat)
            }
            Spacer(minLength: 0)
        }
    }

    private func legend(_ name: String, _ grams: Double?, _ color: Color) -> some View {
        HStack(spacing: 8) {
            MacroDot(color: color, size: 12)
            Text("\(Format.grams(grams))g").font(.headline).foregroundStyle(color)
            Text(name).foregroundStyle(Theme.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Edit a logged entry: amount, unit, meal, or delete.
struct EntryEditorSheet: View {
    let entry: DiaryEntry
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double = 1
    @State private var unit = ServingUnit.gram
    @State private var meal: MealSlot = .breakfast
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            let portion = entry.portion
            let preview = FoodPortion(food: portion.food, amount: amount, unit: unit).nutrients
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        FoodIcon(group: portion.food.group, imageURL: portion.food.imageURL.flatMap { URL(string: $0) }, size: 52)
                        VStack(alignment: .leading) {
                            Text(portion.food.name).font(.title3.bold()).foregroundStyle(Theme.textPrimary)
                            if let detail = portion.food.detail { Text(detail).font(.caption).foregroundStyle(Theme.textSecondary).lineLimit(2) }
                        }
                    }
                    LTCard { NutritionSummary(nutrients: preview) }
                    Text("Amount").font(.headline).foregroundStyle(Theme.textPrimary)
                    ServingPicker(amount: $amount, unit: $unit, units: portion.food.units)
                    Text("Meal").font(.headline).foregroundStyle(Theme.textPrimary)
                    MealPicker(meal: $meal)
                    Button("Save") { save() }
                        .buttonStyle(LTPrimaryButtonStyle())
                        .disabled(amount <= 0)
                        .padding(.top, 8)
                        .accessibilityIdentifier("entry.save")
                    Button("Delete", role: .destructive) {
                        DiaryService.delete(entry, in: context)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("entry.delete")
                }
                .padding(Theme.screenPadding)
            }
            .background(Theme.background)
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onAppear {
                guard !loaded else { return }
                amount = portion.amount
                unit = portion.unit
                meal = entry.meal
                loaded = true
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        var portion = entry.portion
        portion.amount = amount
        portion.unit = unit
        entry.portion = portion
        entry.meal = meal
        try? context.save()
        dismiss()
    }
}

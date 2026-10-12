import SwiftUI
import SwiftData

/// Log or edit exercise. The owner types the calories (from a watch or machine); LeanTrack doesn't guess them.
struct ExerciseSheet: View {
    let entry: ExerciseEntry?
    let day: Date
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var minutes: Double = 30
    @State private var kcal: Double = 0
    @State private var loaded = false

    private let suggestions = ["Walking", "Running", "Cycling", "Strength training", "Swimming", "Yoga", "Sports", "Hiking"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Walking", text: $name).accessibilityIdentifier("exercise.name")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(suggestions, id: \.self) { s in
                                FilterChip(title: s, selected: name == s) { name = s }
                            }
                        }
                    }
                    LabeledContent("Minutes") { NumberField(placeholder: "min", value: $minutes, decimals: 0) }
                    LabeledContent("Calories burned") { NumberField(placeholder: "cal", value: $kcal, decimals: 0) }
                        .accessibilityIdentifier("exercise.kcal")
                } header: {
                    Text("Exercise")
                } footer: {
                    Text("Use the number from your watch, app or machine. These are often higher than what you really burned, so adding them back to your goal is off by default (Goals → Calorie Goal).")
                }
                if let entry {
                    Section {
                        Button("Delete Exercise", role: .destructive) {
                            context.delete(entry)
                            try? context.save()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(entry == nil ? "Add Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || kcal < 0 || minutes < 0)
                        .accessibilityIdentifier("exercise.save")
                }
            }
            .onAppear {
                guard !loaded, let entry else { return }
                loaded = true
                name = entry.name; minutes = entry.minutes; kcal = entry.kcal
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let entry {
            entry.name = trimmed; entry.minutes = minutes; entry.kcal = kcal
        } else {
            context.insert(ExerciseEntry(name: trimmed, minutes: minutes, kcal: kcal, day: day))
        }
        try? context.save()
        dismiss()
    }
}

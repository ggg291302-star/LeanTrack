import SwiftUI

/// Big blue button ("Add to Diary").
struct LTPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.accent.opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4),
                        in: RoundedRectangle(cornerRadius: 25, style: .continuous))
    }
}

struct LTSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.accent)
            .frame(minWidth: 90, minHeight: 50)
            .padding(.horizontal, 12)
            .background(Theme.card.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 25, style: .continuous))
    }
}

/// "Label ........ field" row.
struct LabeledField<Field: View>: View {
    let title: String
    @ViewBuilder var field: Field

    init(_ title: String, @ViewBuilder field: () -> Field) {
        self.title = title
        self.field = field()
    }

    var body: some View {
        HStack {
            Text(title).foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 12)
            field.foregroundStyle(Theme.textPrimary)
        }
    }
}

/// A number field with a unit after it. Empty or invalid input keeps the old value.
struct NumberField: View {
    let placeholder: String
    @Binding var value: Double
    var unit: String = ""
    var decimals: Int = 1
    var width: CGFloat = 80

    var body: some View {
        HStack(spacing: 4) {
            TextField(placeholder, value: $value, format: .number.precision(.fractionLength(0...decimals)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: width)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(Theme.cardElevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            if !unit.isEmpty {
                Text(unit).foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

/// Weight in the owner's unit, stored in kilograms.
struct WeightField: View {
    let title: String
    @Binding var kg: Double
    let unit: WeightUnit

    var body: some View {
        LabeledField(title) {
            NumberField(placeholder: unit == .kg ? "kg" : "lb", value: Binding(
                get: { unit == .kg ? (kg * 10).rounded() / 10 : (UnitConversion.pounds(fromKilograms: kg) * 10).rounded() / 10 },
                set: { kg = unit == .kg ? $0 : UnitConversion.kilograms(fromPounds: $0) }
            ), unit: unit.rawValue)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

/// Height in ft/in or cm, stored in centimeters.
struct HeightField: View {
    @Binding var heightCm: Double
    let unit: HeightUnit

    var body: some View {
        LabeledField("Height") {
            if unit == .cm {
                NumberField(placeholder: "cm", value: Binding(get: { heightCm.rounded() }, set: { heightCm = $0 }), unit: "cm", decimals: 0)
            } else {
                let parts = UnitConversion.feetAndInches(fromCentimeters: heightCm)
                HStack(spacing: 6) {
                    NumberField(placeholder: "ft", value: Binding(
                        get: { Double(parts.feet) },
                        set: { heightCm = UnitConversion.centimeters(feet: Int(max(0, $0)), inches: parts.inches) }
                    ), unit: "ft", decimals: 0, width: 44)
                    NumberField(placeholder: "in", value: Binding(
                        get: { parts.inches.rounded() },
                        set: { heightCm = UnitConversion.centimeters(feet: parts.feet, inches: max(0, min($0, 11.9))) }
                    ), unit: "in", decimals: 0, width: 44)
                }
            }
        }
    }
}

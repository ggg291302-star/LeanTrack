import SwiftUI

/// A food in a list: icon, name, "amount · cal • P • C • F", and an optional quick-add "+".
struct FoodRow: View {
    let portion: FoodPortion
    var subtitle: String? = nil
    var onAdd: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            FoodIcon(group: portion.food.group, imageURL: portion.food.imageURL.flatMap { URL(string: $0) })
            VStack(alignment: .leading, spacing: 3) {
                Text(portion.food.name)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .accessibilityIdentifier("foodRow.name")
                Text(subtitle ?? "\(portion.amountText) · \(Format.macroLine(portion.nutrients))")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 4)
            if let onAdd {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Quick add \(portion.food.name), \(portion.amountText)")
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, onAdd == nil ? 14 : 4)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

/// Rows inside one rounded card, with dividers between them.
struct LTCardList<Data: RandomAccessCollection, Row: View>: View where Data.Element: Identifiable {
    let items: Data
    var dividerInset: CGFloat = 70
    @ViewBuilder var row: (Data.Element) -> Row

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                row(item)
                if index < items.count - 1 { LTRowDivider(leadingInset: dividerInset) }
            }
        }
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

/// Section title above a card ("Breakfast", "Ingredients").
struct LTSectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title).font(.headline).foregroundStyle(Theme.textPrimary)
            Spacer()
            if let trailing { Text(trailing).font(.subheadline).foregroundStyle(Theme.textSecondary) }
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Underlined tabs like "Recent  Favorites  Common  Brands" in the design.
struct UnderlineTabs<Tab: Hashable & Identifiable>: View {
    let tabs: [Tab]
    @Binding var selection: Tab
    let title: (Tab) -> String
    var idPrefix = "tab"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 22) {
                    ForEach(tabs) { tab in
                        let selected = tab == selection
                        Button {
                            selection = tab
                            withAnimation { proxy.scrollTo(tab.id, anchor: .center) }
                        } label: {
                            VStack(spacing: 8) {
                                Text(title(tab))
                                    .font(.subheadline.weight(selected ? .semibold : .regular))
                                    .foregroundStyle(selected ? Theme.accent : Theme.textPrimary)
                                Capsule().fill(selected ? Theme.accent : .clear).frame(height: 3)
                            }
                            .fixedSize()
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .id(tab.id)
                        .accessibilityAddTraits(selected ? [.isSelected] : [])
                        .accessibilityIdentifier("\(idPrefix).\(tab.id)")
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.separator).frame(height: 0.5) }
    }
}

/// Every nutrient for an amount, with % Daily Value. Missing values show "—".
struct NutrientFactsCard: View {
    let nutrients: Nutrients
    var title = "Nutrition Facts"
    /// Goals to compare against instead of the Daily Value (by nutrient key).
    var goals: [String: Double] = [:]
    /// How many foods were missing each nutrient (day totals).
    var missing: [String: Int] = [:]
    var showAll = false
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(NutrientInfo.sections.enumerated()), id: \.offset) { index, section in
                if index == 0 || expanded || showAll {
                    Text(index == 0 ? title : section.title).font(.headline).foregroundStyle(Theme.textPrimary).padding(.top, index == 0 ? 0 : 8)
                    VStack(spacing: 0) {
                        ForEach(section.keys, id: \.self) { key in
                            if let info = NutrientInfo.info(for: key) { row(info) }
                        }
                    }
                }
            }
            if !showAll {
                Button(expanded ? "Show less" : "Show vitamins & minerals") { withAnimation { expanded.toggle() } }
                    .font(.subheadline)
                    .padding(.top, 4)
            }
            if !missing.isEmpty {
                Text("* Some foods don't list this nutrient, so the real total is likely higher.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Text("% Daily Value is based on the FDA's Daily Values for a 2,000-calorie diet.")
                .font(.caption).foregroundStyle(Theme.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private func row(_ info: NutrientInfo) -> some View {
        let value = nutrients[keyPath: info.keyPath]
        let goal = goals[info.key] ?? info.dailyValue
        let percent: Int? = {
            guard let value, let goal, goal > 0 else { return nil }
            return Int((value / goal * 100).rounded())
        }()
        return VStack(spacing: 0) {
            HStack {
                Text(info.name + (missing[info.key] != nil && value != nil ? "*" : ""))
                    .font(info.indented ? .subheadline : .subheadline.weight(.semibold))
                    .foregroundStyle(info.indented ? Theme.textSecondary : Theme.textPrimary)
                    .padding(.leading, info.indented ? 14 : 0)
                Spacer()
                Text(info.format(value)).font(.subheadline).foregroundStyle(Theme.textPrimary).monospacedDigit()
                Text(percent.map { "\($0)%" } ?? "")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 48, alignment: .trailing)
                    .monospacedDigit()
            }
            .padding(.vertical, 7)
            Rectangle().fill(Theme.separator).frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Short message at the bottom of the screen ("Added to Lunch").
struct ToastView: View {
    let message: String
    var body: some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(white: 0.22), in: Capsule())
            .shadow(radius: 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityIdentifier("toast")
    }
}

/// A small rounded "chip" for filters.
struct FilterChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.white : Theme.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(selected ? Theme.accent : Theme.card, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

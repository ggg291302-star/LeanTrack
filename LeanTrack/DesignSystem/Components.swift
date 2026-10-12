import SwiftUI

/// The dark-gray rounded card used all over the app.
struct LTCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

/// Centered screen title like "Food Diary" in the design reference.
struct LTScreenTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Friendly placeholder shown on screens that are not built yet.
struct LTComingSoon: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        LTCard(padding: 24) {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(Theme.textPrimary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One row in a card list (More, Settings): icon, title, optional value, chevron.
struct LTListRow: View {
    let systemImage: String
    let title: String
    var value: String? = nil
    var iconColor: Color = Theme.textPrimary

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(iconColor)
                .frame(width: 26)
                .accessibilityHidden(true)
            Text(title)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 8)
            if let value {
                Text(value)
                    .foregroundStyle(Theme.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
        }
        .font(.body)
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

/// Thin divider inset to line up with row text.
struct LTRowDivider: View {
    var leadingInset: CGFloat = 56

    var body: some View {
        Rectangle()
            .fill(Theme.separator)
            .frame(height: 0.5)
            .padding(.leading, leadingInset)
    }
}

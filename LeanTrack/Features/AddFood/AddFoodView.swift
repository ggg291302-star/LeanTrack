import SwiftUI

struct AddFoodView: View {
    let meal: MealSlot
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.cardSpacing) {
                    searchField
                    LTComingSoon(
                        systemImage: "magnifyingglass",
                        title: "Adding to \(meal.title)",
                        message: "Food search, Recent, Favorites, Common, Recipes, Brands and the barcode scanner will show up here in Stage 3."
                    )
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 8)
            }
            .background(Theme.background)
            .navigationTitle("Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("addFood.cancel")
                }
                ToolbarItem(placement: .primaryAction) {
                    Image(systemName: "barcode.viewfinder")
                        .foregroundStyle(Theme.textSecondary)
                        .accessibilityLabel("Scan barcode (coming soon)")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .accessibilityHidden(true)
            Text("Search for a food…")
            Spacer()
        }
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Theme.cardElevated, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    AddFoodView(meal: .lunch)
}

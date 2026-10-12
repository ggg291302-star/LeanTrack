import SwiftUI

/// Big green ring from the design reference: eaten vs goal.
struct CalorieRing: View {
    let eaten: Double
    let goal: Int
    var lineWidth: CGFloat = 16

    private var progress: Double { goal > 0 ? eaten / Double(goal) : 0 }

    var body: some View {
        ZStack {
            Circle().stroke(Theme.cardElevated, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(progress > 1 ? Theme.fat : Theme.calorieRing, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(Format.calories(eaten))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("of \(goal.formatted())")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Text("Calories")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(lineWidth * 1.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Format.calories(eaten)) of \(goal.formatted()) calories eaten")
    }
}

/// Donut split by each macro's share of calories, with the fixed macro colors.
struct MacroDonut: View {
    let protein: Double
    let carbs: Double
    let fat: Double
    var lineWidth: CGFloat = 14

    var body: some View {
        let shares = NutritionMath.macroShares(protein: protein, carbs: carbs, fat: fat)
        let parts: [(Double, Color)] = [(shares.protein, Theme.protein), (shares.carbs, Theme.carbs), (shares.fat, Theme.fat)]
        ZStack {
            Circle().stroke(Theme.cardElevated, lineWidth: lineWidth)
            ForEach(0..<3, id: \.self) { i in
                let start = parts[..<i].map(\.0).reduce(0, +) / 100
                let end = start + parts[i].0 / 100
                Circle()
                    .trim(from: start, to: end)
                    .stroke(parts[i].1, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: "Protein %.0f percent, carbs %.0f percent, fat %.0f percent of calories", shares.protein, shares.carbs, shares.fat))
    }
}

/// Small horizontal progress bar.
struct LTProgressBar: View {
    let value: Double
    let color: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.cardElevated)
                Capsule().fill(color).frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Colored dot used in legends and macro labels.
struct MacroDot: View {
    let color: Color
    var size: CGFloat = 10
    var body: some View {
        Circle().fill(color).frame(width: size, height: size).accessibilityHidden(true)
    }
}

/// Round food icon: a photo when there is one, otherwise an emoji for the food group.
struct FoodIcon: View {
    let group: String
    var imageURL: URL? = nil
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(Theme.cardElevated)
            if let imageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    emoji
                }
                .clipShape(Circle())
            } else {
                emoji
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var emoji: some View {
        Text(Self.emoji(for: group)).font(.system(size: size * 0.5))
    }

    static func emoji(for group: String) -> String {
        switch group {
        case "fruit": "🍎"
        case "vegetable": "🥦"
        case "poultry": "🍗"
        case "meat": "🥩"
        case "fish": "🐟"
        case "egg": "🥚"
        case "dairy": "🥛"
        case "grain": "🍚"
        case "cereal": "🥣"
        case "bakery": "🍞"
        case "legume": "🫘"
        case "nuts": "🥜"
        case "fat": "🫒"
        case "sweets": "🍰"
        case "drink": "🥤"
        case "snack": "🍿"
        case "fastfood": "🍔"
        case "soup": "🍲"
        case "meal": "🍽️"
        case "spice": "🧂"
        case "baby": "🍼"
        default: "🍴"
        }
    }
}

/// A recipe's bundled photo, or the meal icon when it has none.
struct RecipeImage: View {
    let recipe: Recipe
    var height: CGFloat = 180
    var cornerRadius: CGFloat = Theme.cornerRadius

    var body: some View {
        // The photo fills a fixed box as an overlay, so it can never push the layout wider.
        Theme.cardElevated
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .overlay {
                if let url = RecipeLibrary.photoURL(for: recipe), let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Text("🍽️").font(.system(size: height * 0.35))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }
}

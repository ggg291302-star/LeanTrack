import SwiftUI
import SwiftData

/// Food from a photo: Apple's on-device classifier suggests what the food is (nothing is uploaded),
/// and the owner picks the matching USDA food and the amount.
struct PhotoFoodView: View {
    let image: UIImage
    let day: Date
    let onLogged: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var meal: MealSlot
    @State private var guesses: [FoodRecognizer.Guess] = []
    @State private var classifying = true
    @State private var path = NavigationPath()

    init(image: UIImage, meal: MealSlot, day: Date, onLogged: @escaping (String) -> Void) {
        self.image = image
        self.day = day
        self.onLogged = onLogged
        _meal = State(initialValue: meal)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                        .accessibilityLabel("Your food photo")
                    MealPicker(meal: $meal)
                    LTSectionHeader(title: "What it looks like", trailing: "On this iPhone")
                    if classifying {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if guesses.isEmpty {
                        LTCard {
                            Text("Your iPhone didn't recognize a food in this photo. Go back and search for it, or scan its barcode.")
                                .font(.subheadline).foregroundStyle(Theme.textSecondary)
                        }
                    } else {
                        ForEach(guesses) { guess in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(guess.label.capitalized) · \(Int((guess.confidence * 100).rounded()))% sure")
                                    .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                                LTCardList(items: guess.matches.compactMap { s in FoodDatabase.shared?.food(id: s.id).map { FoodPortion.defaultFor($0) } }) { portion in
                                    FoodRow(portion: portion).onTapGesture { path.append(portion) }
                                }
                            }
                        }
                        Text("Pick the closest match, then set the amount. A photo can't measure portion size on its own.")
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(Theme.screenPadding)
            }
            .background(Theme.background)
            .navigationTitle("Food Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .navigationDestination(for: FoodPortion.self) { portion in
                FoodDetailView(portion: portion, mode: .log(day: day), meal: meal) { message in
                    if let message { onLogged(message) }
                    dismiss()
                }
            }
            .task {
                guesses = (try? await FoodRecognizer.classify(image)) ?? []
                classifying = false
            }
        }
    }
}

import Foundation
import UIKit
import Vision

/// On-device food recognition with Apple's Vision image classifier. Nothing leaves the phone.
/// It names what it sees ("pizza", "banana"); the owner picks the matching USDA food and amount.
enum FoodRecognizer {
    struct Guess: Identifiable, Hashable {
        let label: String
        let confidence: Float
        let matches: [FoodSummary]
        var id: String { label }
    }

    /// Labels from Apple's classifier that aren't foods themselves.
    static let ignoredLabels: Set<String> = [
        "food", "dish", "meal", "cuisine", "produce", "fruit", "vegetable", "dessert", "baked goods", "snack", "drink", "beverage",
        "tableware", "plate", "bowl", "cup", "mug", "glass", "utensil", "fork", "spoon", "knife", "chopsticks", "cutlery", "table",
        "dining table", "placemat", "napkin", "tray", "container", "jar", "bottle", "can", "box", "package", "wood", "wood processed",
        "textile", "indoor", "outdoor", "people", "adult", "hand", "finger", "structure", "kitchen", "restaurant", "counter",
        "board", "cutting board", "paper", "material", "liquid", "sauce", "herb", "spice", "garnish", "ingredient",
    ]

    /// "fried_egg" → "fried egg".
    static func cleanLabel(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: " ").trimmingCharacters(in: .whitespaces).lowercased()
    }

    static func classify(_ image: UIImage, database: FoodDatabase? = FoodDatabase.shared) async throws -> [Guess] {
        guard let cgImage = image.cgImage else { return [] }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let observations: [VNClassificationObservation] = try await Task.detached(priority: .userInitiated) {
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
            try handler.perform([request])
            return request.results ?? []
        }.value

        var guesses: [Guess] = []
        for obs in observations.sorted(by: { $0.confidence > $1.confidence }).prefix(40) where obs.confidence >= 0.05 {
            let label = cleanLabel(obs.identifier)
            guard !ignoredLabels.contains(label) else { continue }
            let matches = database?.search(label, limit: 6) ?? []
            // Keep labels whose words actually show up in a matching food name.
            let words = label.split(separator: " ").map(String.init)
            let relevant = matches.filter { m in words.contains { m.name.lowercased().contains($0) || m.usdaName.lowercased().contains($0) } }
            guard !relevant.isEmpty else { continue }
            guesses.append(Guess(label: label, confidence: obs.confidence, matches: relevant))
            if guesses.count == 6 { break }
        }
        return guesses
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// Optional AI photo estimate with the Claude API, using the owner's own Anthropic API key
/// (stored in the Keychain; the owner pays Anthropic for each photo, usually a few cents).
/// Claude only names the foods and estimates their weight in grams. The calories and
/// nutrients always come from the USDA database, so the numbers stay real data.
enum ClaudeFoodEstimator {
    static let model = "claude-opus-5-5"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    struct Item: Codable, Hashable {
        var name: String
        var search_terms: String
        var grams: Double
        var confidence: String
    }

    struct Estimate: Codable, Hashable {
        var items: [Item]
        var notes: String
    }

    enum EstimateError: LocalizedError {
        case noKey, badKey, rateLimited, overloaded, refused, noFoodText, network(String), api(Int, String)

        var errorDescription: String? {
            switch self {
            case .noKey: "Add your Anthropic API key in Settings → AI Photo Estimates first."
            case .badKey: "Anthropic rejected the API key. Check it in Settings → AI Photo Estimates."
            case .rateLimited: "Too many AI requests right now. Wait a minute and try again."
            case .overloaded: "Claude is busy right now. Try again in a minute."
            case .refused: "Claude declined to analyze this photo. Try a different photo, or use the on-device results."
            case .noFoodText: "Claude's answer couldn't be read. Try again."
            case .network(let message): "Couldn't reach Claude: \(message)"
            case .api(let status, let message): "Claude API error \(status): \(message)"
            }
        }
    }

    static let systemPrompt = """
    You estimate food portions from photos for a calorie-tracking app. The app looks up calories and nutrients \
    in the USDA FoodData Central database itself, so your job is only to name each food and estimate its weight.
    """

    static let userPrompt = """
    Identify each separate food or drink in this photo and estimate the edible weight in grams of each, as served.
    - Use visual cues for scale: a dinner plate is about 26 cm (10 in) across, a fork about 19 cm, a typical mug holds about 350 ml.
    - Split a plate into its parts when you can tell them apart (for example chicken, rice and broccoli). If a mixed dish can't be split, name the dish (for example "lasagna" or "beef stew").
    - For search_terms, give 1 to 4 plain words that would find the item in the USDA database, including the cooking method when you can see it (for example "chicken breast roasted", "rice white cooked", "broccoli cooked", "egg fried").
    - Count visible cooking oil, butter or dressing as its own item when there's a clear amount.
    - confidence is "high", "medium" or "low" for each item.
    - If there's no food in the photo, return an empty items list.
    - notes: one or two short sentences about what limits the estimate (hidden oil, sauces, food out of view).
    """

    static let schema: [String: Any] = {
        let item: [String: Any] = [
            "type": "object",
            "properties": [
                "name": ["type": "string"],
                "search_terms": ["type": "string"],
                "grams": ["type": "number"],
                "confidence": ["type": "string", "enum": ["high", "medium", "low"]] as [String: Any],
            ] as [String: Any],
            "required": ["name", "search_terms", "grams", "confidence"],
            "additionalProperties": false,
        ]
        let items: [String: Any] = ["type": "array", "items": item]
        return [
            "type": "object",
            "properties": ["items": items, "notes": ["type": "string"]] as [String: Any],
            "required": ["items", "notes"],
            "additionalProperties": false,
        ]
    }()

    /// JPEG, longest side at most 1,024 px (plenty for portion estimates, and cheaper).
    static func jpegData(_ image: UIImage, maxSide: CGFloat = 1024) -> Data? {
        let size = image.size
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: 0.75)
    }

    static func requestBody(imageJPEG: Data) throws -> Data {
        let image: [String: Any] = [
            "type": "image",
            "source": ["type": "base64", "media_type": "image/jpeg", "data": imageJPEG.base64EncodedString()],
        ]
        let text: [String: Any] = ["type": "text", "text": userPrompt]
        let message: [String: Any] = ["role": "user", "content": [image, text]]
        let format: [String: Any] = ["type": "json_schema", "schema": schema]
        let outputConfig: [String: Any] = ["effort": "medium", "format": format]
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 16000,
            // Server-side fallback: if a safety classifier declines, the API retries on the recommended model.
            "fallbacks": "default",
            "output_config": outputConfig,
            "system": systemPrompt,
            "messages": [message],
        ]
        return try JSONSerialization.data(withJSONObject: body)
    }

    static func estimate(image: UIImage) async throws -> Estimate {
        guard let key = KeychainStore.string(for: .anthropicAPIKey) else { throw EstimateError.noKey }
        guard let jpeg = jpegData(image) else { throw EstimateError.noFoodText }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try requestBody(imageJPEG: jpeg)

        let data: Data
        let response: URLResponse
        do { (data, response) = try await URLSession.shared.data(for: request) }
        catch { throw EstimateError.network(error.localizedDescription) }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return try parseResponse(data, status: status)
    }

    /// Reads a Messages API response: checks the stop reason, then decodes the JSON text block.
    static func parseResponse(_ data: Data, status: Int) throws -> Estimate {
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard status == 200 else {
            let message = ((json["error"] as? [String: Any])?["message"] as? String) ?? "Unknown error"
            switch status {
            case 401, 403: throw EstimateError.badKey
            case 429: throw EstimateError.rateLimited
            case 529, 503: throw EstimateError.overloaded
            default: throw EstimateError.api(status, message)
            }
        }
        let stopReason = json["stop_reason"] as? String
        if stopReason == "refusal" { throw EstimateError.refused }
        if stopReason == "max_tokens" { throw EstimateError.noFoodText }
        let blocks = json["content"] as? [[String: Any]] ?? []
        guard let text = blocks.first(where: { $0["type"] as? String == "text" })?["text"] as? String,
              let estimate = try? JSONDecoder().decode(Estimate.self, from: Data(text.utf8))
        else { throw EstimateError.noFoodText }
        return estimate
    }
}

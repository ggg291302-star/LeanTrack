import Foundation

/// In-memory, typo-tolerant search over the food names.
///
/// Every word of a food's short name and USDA name goes into a vocabulary. A search word
/// matches a vocabulary word exactly, as a prefix ("chick" → "chicken"), or with one or two
/// typos ("chiken" → "chicken", "brest" → "breast"). A food matches when every search word
/// matches one of its words. Results are ranked so Common foods and close name matches come first.
struct FoodSearchIndex: Sendable {
    private let vocabulary: [[UInt8]]
    private let vocabularyIDs: [String: Int32]
    private let wordsByLength: [Int: [Int32]]
    /// For each vocabulary word, the foods that contain it: food index × 2 (+1 when it's in the short name).
    private let postings: [[Int32]]
    private let firstWord: [Int32]
    private let nameLength: [Int16]
    private let boosted: [Bool]
    private let hasCalories: [Bool]

    private static let stopWords: Set<String> = ["and", "with", "of", "the", "a", "an", "in", "or", "for", "to"]

    init(foods: [FoodSummary], boosted boostedIDs: Set<Int>) {
        var vocabularyIDs: [String: Int32] = [:]
        var vocabulary: [[UInt8]] = []
        var postings: [[Int32]] = []
        var firstWord = [Int32](repeating: -1, count: foods.count)
        var nameLength = [Int16](repeating: 0, count: foods.count)

        func id(for word: String) -> Int32 {
            if let existing = vocabularyIDs[word] { return existing }
            let new = Int32(vocabulary.count)
            vocabularyIDs[word] = new
            vocabulary.append(Array(word.utf8))
            postings.append([])
            return new
        }

        for (index, food) in foods.enumerated() {
            let shortWords = Self.words(food.name)
            let usdaWords = Self.words(food.usdaName)
            nameLength[index] = Int16(min(food.name.count, Int(Int16.max)))
            var seen: [Int32: Bool] = [:]
            for word in shortWords { seen[id(for: word)] = true }
            for word in usdaWords where seen[id(for: word)] == nil { seen[id(for: word)] = false }
            for (wordID, inShort) in seen {
                postings[Int(wordID)].append(Int32(index) * 2 + (inShort ? 1 : 0))
            }
            if let first = shortWords.first { firstWord[index] = vocabularyIDs[first] ?? -1 }
        }

        var byLength: [Int: [Int32]] = [:]
        for (i, word) in vocabulary.enumerated() { byLength[word.count, default: []].append(Int32(i)) }

        self.vocabulary = vocabulary
        self.vocabularyIDs = vocabularyIDs
        self.wordsByLength = byLength
        self.postings = postings
        self.firstWord = firstWord
        self.nameLength = nameLength
        self.boosted = foods.map { boostedIDs.contains($0.id) }
        self.hasCalories = foods.map { $0.kcalPer100g != nil }
    }

    /// Lowercase words with accents removed ("Jalapeño, raw" → ["jalapeno", "raw"]).
    static func words(_ text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .lowercased()
            .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
            .map(String.init)
    }

    /// Indices into the `foods` array given to `init`, best match first.
    func search(_ text: String, limit: Int = 50) -> [Int] {
        let queryWords = Self.words(text)
        let required = queryWords.filter { !Self.stopWords.contains($0) }
        let terms = required.isEmpty ? queryWords : required
        guard !terms.isEmpty else { return [] }

        let count = firstWord.count
        var total = [Float](repeating: 0, count: count)
        var matched = [UInt8](repeating: 0, count: count)
        var touched: [Int32] = []
        var firstTermWords: Set<Int32> = []

        for (termIndex, term) in terms.enumerated() {
            let matches = vocabularyMatches(for: term)
            if termIndex == 0 { firstTermWords = Set(matches.map(\.word)) }
            var best: [Int32: Float] = [:]
            for match in matches {
                for posting in postings[Int(match.word)] {
                    let food = posting >> 1
                    let score = match.score * ((posting & 1) == 1 ? 1 : 0.85)
                    if score > best[food, default: 0] { best[food] = score }
                }
            }
            for (food, score) in best {
                let i = Int(food)
                if matched[i] == 0 { touched.append(food) }
                matched[i] += 1
                total[i] += score
            }
        }

        let needed = UInt8(terms.count)
        var results = touched.filter { matched[Int($0)] == needed }
        var partial = false
        if results.count < 5 && terms.count >= 2 {
            results = touched.filter { matched[Int($0)] >= needed - 1 }
            partial = true
        }

        func rank(_ food: Int32) -> Float {
            let i = Int(food)
            var score = total[i]
            if partial && matched[i] < needed { score -= 1 }
            if boosted[i] { score += 0.6 }
            if firstTermWords.contains(firstWord[i]) { score += 0.4 }
            if !hasCalories[i] { score -= 0.5 }
            score -= Float(nameLength[i]) * 0.004
            return score
        }

        let scored = results.map { (food: $0, score: rank($0)) }
        return scored
            .sorted { $0.score != $1.score ? $0.score > $1.score : nameLength[Int($0.food)] < nameLength[Int($1.food)] }
            .prefix(limit)
            .map { Int($0.food) }
    }

    private struct Match { let word: Int32; let score: Float }

    private func vocabularyMatches(for term: String) -> [Match] {
        let query = Array(term.utf8)
        var matches: [Match] = []
        if let exact = vocabularyIDs[term] { matches.append(Match(word: exact, score: 1)) }

        // Prefix: "chick" → "chicken", "straw" → "strawberries"
        if query.count >= 2 {
            for length in (query.count + 1)...(query.count + 12) {
                for id in wordsByLength[length] ?? [] where vocabulary[Int(id)].starts(with: query) {
                    matches.append(Match(word: id, score: 0.85 + 0.15 * Float(query.count) / Float(length)))
                }
            }
        }

        // Typos: one edit for 4–7 letters, two for 8+ ("chiken" → "chicken").
        if query.count >= 4 {
            let maxEdits = query.count >= 8 ? 2 : 1
            for length in max(1, query.count - maxEdits)...(query.count + maxEdits) {
                for id in wordsByLength[length] ?? [] {
                    let word = vocabulary[Int(id)]
                    if word == query { continue }
                    if let d = Self.editDistance(query, word, max: maxEdits) {
                        matches.append(Match(word: id, score: 0.75 - 0.1 * Float(d - 1)))
                    }
                }
            }
        }
        return matches
    }

    /// Optimal-string-alignment distance (insert, delete, replace, swap two neighbors),
    /// or nil when it's more than `max`.
    static func editDistance(_ a: [UInt8], _ b: [UInt8], max limit: Int) -> Int? {
        if abs(a.count - b.count) > limit { return nil }
        if a.isEmpty || b.isEmpty { return max(a.count, b.count) <= limit ? max(a.count, b.count) : nil }
        var previous2 = [Int](repeating: 0, count: b.count + 1)
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            var rowMin = current[0]
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                var value = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    value = min(value, previous2[j - 2] + 1)
                }
                current[j] = value
                rowMin = min(rowMin, value)
            }
            if rowMin > limit { return nil }
            (previous2, previous, current) = (previous, current, previous2)
        }
        return previous[b.count] <= limit ? previous[b.count] : nil
    }
}

import Foundation

/// Errors from the online food sources, worded for the owner.
enum OnlineFoodError: LocalizedError, Equatable {
    case offline
    case rateLimited(source: String, usingDemoKey: Bool)
    case badKey
    case server(source: String, status: Int)
    case unreadable(source: String)

    var errorDescription: String? {
        switch self {
        case .offline:
            "You're offline. The 13,000+ built-in USDA foods still work; brand-name foods and barcodes need the internet."
        case .rateLimited(let source, let demo):
            demo
                ? "\(source) is busy: the shared free key allows about 30 searches an hour. Try again later."
                : "\(source) asked LeanTrack to slow down. Try again in a minute."
        case .badKey:
            "USDA rejected the app's API key. Built-in foods still work; brand-name search will be back after an update."
        case .server(let source, let status):
            "\(source) didn't answer properly (error \(status)). Try again later."
        case .unreadable(let source):
            "\(source) sent data LeanTrack couldn't read."
        }
    }

    static func from(_ error: Error) -> OnlineFoodError? {
        if let e = error as? OnlineFoodError { return e }
        if let e = error as? URLError {
            switch e.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .cannotFindHost, .cannotConnectToHost, .timedOut:
                return .offline
            default: return nil
            }
        }
        return nil
    }
}

/// Shared HTTP settings. No personal data is ever sent; the User-Agent only names the app.
enum OnlineHTTP {
    static let userAgent = "LeanTrack/1.0 (iPhone; personal non-commercial app; https://github.com/ggg291302-star/LeanTrack)"

    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.httpAdditionalHeaders = ["User-Agent": userAgent]
        return URLSession(configuration: config)
    }()

    static func get(_ url: URL) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }
}

// MARK: - Barcodes

enum Barcode {
    /// Keeps digits only.
    static func digits(_ text: String) -> String { text.filter(\.isNumber) }

    /// True if the last digit is a valid GTIN check digit (EAN-8, UPC-A, EAN-13, GTIN-14).
    static func hasValidCheckDigit(_ code: String) -> Bool {
        let d = digits(code).compactMap { Int(String($0)) }
        guard [8, 12, 13, 14].contains(d.count) else { return false }
        let body = d.dropLast()
        var sum = 0
        for (i, value) in body.reversed().enumerated() { sum += value * (i % 2 == 0 ? 3 : 1) }
        return (10 - sum % 10) % 10 == d.last
    }

    /// Expands an 8-digit UPC-E code (number system 0 or 1) to its 12-digit UPC-A form.
    static func upcEtoUPCA(_ code: String) -> String? {
        let c = Array(digits(code))
        guard c.count == 8, c[0] == "0" || c[0] == "1" else { return nil }
        let ns = c[0], d = Array(c[1...6]), check = c[7]
        let body: String
        switch d[5] {
        case "0", "1", "2": body = "\(d[0])\(d[1])\(d[5])0000\(d[2])\(d[3])\(d[4])"
        case "3": body = "\(d[0])\(d[1])\(d[2])00000\(d[3])\(d[4])"
        case "4": body = "\(d[0])\(d[1])\(d[2])\(d[3])00000\(d[4])"
        default: body = "\(d[0])\(d[1])\(d[2])\(d[3])\(d[4])0000\(d[5])"
        }
        return "\(ns)\(body)\(check)"
    }

    /// The forms worth trying, best first: as scanned, UPC-E expanded, UPC-A ↔ EAN-13.
    static func candidates(_ code: String) -> [String] {
        let d = digits(code)
        var out: [String] = []
        func add(_ s: String?) { if let s, !s.isEmpty, !out.contains(s) { out.append(s) } }
        add(d)
        if d.count == 8 { add(upcEtoUPCA(d)) }
        for c in out {
            if c.count == 12 { add("0" + c) }
            if c.count == 13, c.hasPrefix("0") { add(String(c.dropFirst())) }
        }
        return out
    }

    /// Codes compare equal when they match after removing leading zeros.
    static func same(_ a: String, _ b: String) -> Bool {
        let x = digits(a).drop { $0 == "0" }, y = digits(b).drop { $0 == "0" }
        return !x.isEmpty && x == y
    }
}

// MARK: - USDA FoodData Central (online, branded foods)

/// USDA FoodData Central API. https://fdc.nal.usda.gov/api-guide (data: CC0 public domain).
/// Uses the owner's key built into the app (BuildConfig, from a GitHub secret), or the shared
/// DEMO_KEY (about 30 requests an hour) when the build has no key.
enum USDAClient {
    static let source = "USDA FoodData Central"
    static var apiKey: String { KeychainStore.string(for: .usdaAPIKey) ?? BuildConfig.usdaAPIKey ?? "DEMO_KEY" }
    static var usingDemoKey: Bool { apiKey == "DEMO_KEY" }

    struct SearchResponse: Decodable {
        var foods: [BrandedFood]?
    }

    struct BrandedFood: Decodable {
        struct Nutrient: Decodable {
            var nutrientId: Int?
            var unitName: String?
            var value: Double?
        }
        var fdcId: Int
        var description: String
        var dataType: String?
        var gtinUpc: String?
        var brandOwner: String?
        var brandName: String?
        var servingSize: Double?
        var servingSizeUnit: String?
        var householdServingFullText: String?
        var foodNutrients: [Nutrient]?
    }

    static func searchBranded(_ query: String, pageSize: Int = 25) async throws -> [LoggedFood] {
        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "dataType", value: "Branded"),
            URLQueryItem(name: "pageSize", value: String(pageSize)),
        ]
        let (data, status) = try await OnlineHTTP.get(components.url!)
        try check(status: status, data: data)
        return try parseSearch(data).compactMap(loggedFood)
    }

    /// Finds a branded food by its UPC/EAN barcode.
    static func lookup(barcode: String) async throws -> LoggedFood? {
        for code in Barcode.candidates(barcode).prefix(2) {
            var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")!
            components.queryItems = [
                URLQueryItem(name: "api_key", value: apiKey),
                URLQueryItem(name: "query", value: code),
                URLQueryItem(name: "dataType", value: "Branded"),
                URLQueryItem(name: "pageSize", value: "10"),
            ]
            let (data, status) = try await OnlineHTTP.get(components.url!)
            try check(status: status, data: data)
            if let match = try parseSearch(data).first(where: { Barcode.same($0.gtinUpc ?? "", barcode) }) {
                return loggedFood(match)
            }
        }
        return nil
    }

    static func check(status: Int, data: Data) throws {
        switch status {
        case 200: return
        case 429: throw OnlineFoodError.rateLimited(source: source, usingDemoKey: usingDemoKey)
        case 403:
            // USDA (api.data.gov) answers 403 both for a wrong key and when the demo key is over its limit.
            let text = String(data: data, encoding: .utf8) ?? ""
            if text.contains("OVER_RATE_LIMIT") { throw OnlineFoodError.rateLimited(source: source, usingDemoKey: usingDemoKey) }
            throw OnlineFoodError.badKey
        default: throw OnlineFoodError.server(source: source, status: status)
        }
    }

    static func parseSearch(_ data: Data) throws -> [BrandedFood] {
        do { return try JSONDecoder().decode(SearchResponse.self, from: data).foods ?? [] }
        catch { throw OnlineFoodError.unreadable(source: source) }
    }

    /// Branded nutrient values in FoodData Central are per 100 g (or 100 ml for drinks).
    static func loggedFood(_ item: BrandedFood) -> LoggedFood? {
        var per100 = Nutrients()
        var byID: [Int: NutrientValue] = [:]
        for n in item.foodNutrients ?? [] {
            guard let id = n.nutrientId, let value = n.value, byID[id] == nil else { continue }
            byID[id] = NutrientValue(unit: n.unitName ?? "", value: value)
        }
        for info in NutrientInfo.all {
            for id in info.usdaIDs {
                if let n = byID[id], let v = NutrientInfo.convert(n.value, from: n.unit, to: info.unit) {
                    per100[keyPath: info.keyPath] = v
                    break
                }
            }
        }
        // Energy only in kJ (1062), and vitamin D only in IU (1110; 40 IU = 1 µg).
        if per100.kcal == nil, let kj = byID[1062] { per100.kcal = kj.value / 4.184 }
        if per100.vitaminD == nil, let iu = byID[1110], iu.unit.uppercased() == "IU" { per100.vitaminD = iu.value / 40 }
        guard per100.kcal != nil else { return nil }

        let unitText = (item.servingSizeUnit ?? "g").lowercased()
        let isLiquid = unitText == "ml" || unitText == "mlt"
        var units: [ServingUnit] = []
        if let size = item.servingSize, size > 0, ["g", "grm", "ml", "mlt"].contains(unitText) {
            let label = item.householdServingFullText.flatMap { $0.isEmpty ? nil : $0 } ?? "serving"
            units.append(ServingUnit(name: "serving (\(label))", grams: size))
        }
        units += isLiquid ? [ServingUnit(name: "ml", grams: 1), ServingUnit(name: "fl oz", grams: UnitConversion.millilitersPerUSFluidOunce)] : [.gram, .ounce]
        let brand = [item.brandName, item.brandOwner].compactMap { $0 }.first { !$0.isEmpty }
        return LoggedFood(name: titleCase(item.description), detail: brand.map(titleCase), kind: .usdaBranded,
                          refID: String(item.fdcId), group: "other", per100g: per100, perServing: nil, units: units,
                          imageURL: nil, barcode: item.gtinUpc)
    }

    private struct NutrientValue { var unit: String; var value: Double }

    /// USDA branded names are often ALL CAPS.
    static func titleCase(_ text: String) -> String {
        let letters = text.filter(\.isLetter)
        guard !letters.isEmpty, letters == letters.uppercased() else { return text }
        return text.lowercased().capitalized
    }
}

// MARK: - Open Food Facts

/// Open Food Facts: https://world.openfoodfacts.org (database: ODbL; product images: CC BY-SA).
enum OpenFoodFactsClient {
    static let source = "Open Food Facts"
    static let fields = "code,product_name,product_name_en,brands,nutriments,serving_size,serving_quantity,nutrition_data_per,image_front_small_url"

    static func product(barcode: String) async throws -> LoggedFood? {
        for code in Barcode.candidates(barcode).prefix(3) {
            let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(code).json?fields=\(fields)")!
            let (data, status) = try await OnlineHTTP.get(url)
            if status == 404 { continue }
            try check(status: status)
            if let food = try parseProductResponse(data) { return food }
        }
        return nil
    }

    static func search(_ query: String, pageSize: Int = 20) async throws -> [LoggedFood] {
        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")!
        components.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: String(pageSize)),
            URLQueryItem(name: "fields", value: fields),
        ]
        let (data, status) = try await OnlineHTTP.get(components.url!)
        try check(status: status)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OnlineFoodError.unreadable(source: source)
        }
        return ((json["products"] as? [[String: Any]]) ?? []).compactMap(loggedFood)
    }

    static func check(status: Int) throws {
        switch status {
        case 200: return
        case 429, 503: throw OnlineFoodError.rateLimited(source: source, usingDemoKey: false)
        default: throw OnlineFoodError.server(source: source, status: status)
        }
    }

    static func parseProductResponse(_ data: Data) throws -> LoggedFood? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw OnlineFoodError.unreadable(source: source)
        }
        guard (json["status"] as? Int) == 1 || json["status"] as? String == "success",
              let product = json["product"] as? [String: Any] else { return nil }
        var p = product
        if p["code"] == nil { p["code"] = json["code"] }
        return loggedFood(p)
    }

    private static func number(_ any: Any?) -> Double? {
        switch any {
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let s as String: return Double(s.replacingOccurrences(of: ",", with: "."))
        default: return nil
        }
    }

    /// Open Food Facts stores `<nutrient>_100g` in grams (energy-kcal in kcal).
    static func loggedFood(_ product: [String: Any]) -> LoggedFood? {
        let name = [product["product_name"], product["product_name_en"]].compactMap { $0 as? String }.first { !$0.isEmpty }
        guard let name, let nutriments = product["nutriments"] as? [String: Any] else { return nil }
        // When the label was entered per serving (as on US labels), use those numbers and work out
        // per 100 g from the serving size. The `_100g` fields of such entries are sometimes wrong.
        let servingGrams = number(product["serving_quantity"]).flatMap { $0 > 0 ? $0 : nil }
        let perServing = (product["nutrition_data_per"] as? String) == "serving"
            && servingGrams != nil && number(nutriments["energy-kcal_serving"]) != nil
        let suffix = perServing ? "_serving" : "_100g"
        let factor = perServing ? 100 / (servingGrams ?? 100) : 1
        var per100 = Nutrients()
        for info in NutrientInfo.all {
            guard let off = info.offName, let value = number(nutriments["\(off)\(suffix)"]) else { continue }
            let converted = info.unit == "kcal" ? value : NutrientInfo.convert(value, from: "g", to: info.unit)
            per100[keyPath: info.keyPath] = converted.map { $0 * factor }
        }
        if per100.kcal == nil, let kj = number(nutriments["energy\(suffix)"]) { per100.kcal = kj / 4.184 * factor }
        guard let kcal = per100.kcal, kcal <= 900 else { return nil } // over 900 kcal per 100 g is impossible (pure fat is 900)

        var units: [ServingUnit] = []
        if let grams = number(product["serving_quantity"]), grams > 0 {
            let label = (product["serving_size"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "\(Format.number(grams)) g"
            units.append(ServingUnit(name: "serving (\(label))", grams: grams))
        }
        units += [.gram, .ounce]
        let code = product["code"] as? String
        let brand = (product["brands"] as? String)?.split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) }
        return LoggedFood(name: name, detail: brand, kind: .openFoodFacts, refID: code, group: "other",
                          per100g: per100, perServing: nil, units: units,
                          imageURL: product["image_front_small_url"] as? String, barcode: code)
    }
}

// MARK: - Combined brand search

enum BrandSearch {
    struct Result {
        var foods: [LoggedFood] = []
        var errors: [String] = []
    }

    /// Searches USDA Branded and (if turned on) Open Food Facts at the same time.
    static func search(_ query: String, includeOpenFoodFacts: Bool) async -> Result {
        async let usda = capture { try await USDAClient.searchBranded(query) }
        async let off = capture {
            guard includeOpenFoodFacts else { return [] }
            return try await OpenFoodFactsClient.search(query)
        }
        let u = await usda
        let o = await off
        var result = Result()
        // Interleave so both sources show near the top.
        let a = u.foods, b = o.foods
        for i in 0..<max(a.count, b.count) {
            if i < a.count { result.foods.append(a[i]) }
            if i < b.count { result.foods.append(b[i]) }
        }
        let errors = [u.error, o.error].compactMap { $0 }
        if errors.allSatisfy({ $0 == .offline }), !errors.isEmpty {
            result.errors = [OnlineFoodError.offline.localizedDescription]
        } else {
            result.errors = errors.map { $0.localizedDescription }
        }
        return result
    }

    /// Barcode lookup: USDA Branded first (label data from the manufacturers), then Open Food Facts.
    static func lookup(barcode: String, includeOpenFoodFacts: Bool) async throws -> LoggedFood? {
        var firstError: Error?
        do { if let food = try await USDAClient.lookup(barcode: barcode) { return food } }
        catch { firstError = error }
        if includeOpenFoodFacts {
            do { if let food = try await OpenFoodFactsClient.product(barcode: barcode) { return food } }
            catch { if firstError == nil || OnlineFoodError.from(firstError!) == OnlineFoodError.offline { firstError = error } }
        }
        if let firstError {
            if let friendly = OnlineFoodError.from(firstError) { throw friendly }
            throw firstError
        }
        return nil
    }

    private static func capture(_ work: () async throws -> [LoggedFood]) async -> (foods: [LoggedFood], error: OnlineFoodError?) {
        do { return (try await work(), nil) }
        catch { return ([], OnlineFoodError.from(error) ?? .unreadable(source: "The food search")) }
    }
}

import Foundation
import SQLite3

/// Read-only access to the bundled USDA food database (Resources/Data/foods.sqlite).
/// Built by scripts/build-food-db.mjs. Works fully offline.
final class FoodDatabase: @unchecked Sendable {
    enum DatabaseError: Error, LocalizedError {
        case missingFile
        case openFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingFile: "The built-in food database is missing from the app."
            case .openFailed(let message): "The built-in food database couldn't be opened (\(message))."
            }
        }
    }

    static let shared: FoodDatabase? = try? FoodDatabase()

    private var db: OpaquePointer?
    private let lock = NSLock()
    /// All foods in a compact form, for searching. Loaded once.
    let summaries: [FoodSummary]
    let searchIndex: FoodSearchIndex
    /// Date the database was built and the USDA files it came from.
    let meta: [String: String]
    /// The hand-picked Common list, in order.
    let common: [CommonFood]
    private let commonByFoodID: [Int: CommonFood]

    init(url: URL? = Bundle.main.url(forResource: "foods", withExtension: "sqlite", subdirectory: "Data")) throws {
        guard let url else { throw DatabaseError.missingFile }
        var handle: OpaquePointer?
        // immutable=1: the file never changes, so SQLite can skip locking.
        let uri = url.absoluteString + "?immutable=1"
        guard sqlite3_open_v2(uri, &handle, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            sqlite3_close(handle)
            throw DatabaseError.openFailed(message)
        }
        db = handle

        var rows: [FoodSummary] = []
        rows.reserveCapacity(14_000)
        Self.query(handle, "SELECT id, name, usda_name, grp, kcal FROM foods") { stmt in
            rows.append(FoodSummary(
                id: Int(sqlite3_column_int64(stmt, 0)),
                name: Self.text(stmt, 1) ?? "",
                usdaName: Self.text(stmt, 2) ?? "",
                group: Self.text(stmt, 3) ?? "other",
                kcalPer100g: Self.double(stmt, 4)
            ))
        }
        summaries = rows

        var commonItems: [CommonFood] = []
        Self.query(handle, "SELECT rank, food_id, name, portion_amount, portion_unit, portion_grams FROM common ORDER BY rank") { stmt in
            commonItems.append(CommonFood(
                rank: Int(sqlite3_column_int64(stmt, 0)),
                foodID: Int(sqlite3_column_int64(stmt, 1)),
                name: Self.text(stmt, 2) ?? "",
                portion: Portion(amount: sqlite3_column_double(stmt, 3), unit: Self.text(stmt, 4) ?? "", grams: sqlite3_column_double(stmt, 5))
            ))
        }
        common = commonItems
        var byFood: [Int: CommonFood] = [:]
        for item in commonItems where byFood[item.foodID] == nil { byFood[item.foodID] = item }
        commonByFoodID = byFood
        searchIndex = FoodSearchIndex(foods: rows, boosted: Set(commonItems.map(\.foodID)))

        var meta: [String: String] = [:]
        Self.query(handle, "SELECT key, value FROM meta") { stmt in
            meta[Self.text(stmt, 0) ?? ""] = Self.text(stmt, 1) ?? ""
        }
        self.meta = meta
    }

    deinit {
        sqlite3_close(db)
    }

    var foodCount: Int { summaries.count }

    /// Full details for one food, including every nutrient and USDA portion.
    func food(id: Int) -> Food? {
        lock.lock()
        defer { lock.unlock() }
        let columns = (["id", "name", "usda_name", "source", "category", "grp", "filled_from"] + Nutrients.columns).joined(separator: ", ")
        var food: Food?
        Self.query(db, "SELECT \(columns) FROM foods WHERE id = ?", bind: { sqlite3_bind_int64($0, 1, Int64(id)) }) { stmt in
            var nutrients = Nutrients()
            for (offset, path) in Nutrients.allKeyPaths.enumerated() {
                nutrients[keyPath: path] = Self.double(stmt, Int32(7 + offset))
            }
            food = Food(
                id: Int(sqlite3_column_int64(stmt, 0)),
                name: Self.text(stmt, 1) ?? "",
                usdaName: Self.text(stmt, 2) ?? "",
                source: FoodSource(rawValue: Self.text(stmt, 3) ?? "S") ?? .srLegacy,
                category: Self.text(stmt, 4),
                group: Self.text(stmt, 5) ?? "other",
                filledFromID: sqlite3_column_type(stmt, 6) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(stmt, 6)),
                nutrients: nutrients,
                portions: []
            )
        }
        guard let found = food else { return nil }
        var portions: [Portion] = []
        Self.query(db, "SELECT amount, unit, grams FROM portions WHERE food_id = ? ORDER BY seq", bind: { sqlite3_bind_int64($0, 1, Int64(id)) }) { stmt in
            portions.append(Portion(amount: sqlite3_column_double(stmt, 0), unit: Self.text(stmt, 1) ?? "", grams: sqlite3_column_double(stmt, 2)))
        }
        return Food(id: found.id, name: found.name, usdaName: found.usdaName, source: found.source, category: found.category,
                    group: found.group, filledFromID: found.filledFromID, nutrients: found.nutrients, portions: portions)
    }

    /// The hand-picked Common list, in order.
    func commonFoods() -> [CommonFood] { common }

    /// The Common-list entry for a food, if it has one (gives its everyday portion).
    func commonEntry(foodID: Int) -> CommonFood? { commonByFoodID[foodID] }

    /// Fast, typo-tolerant search ("chiken brest" finds chicken breast).
    func search(_ text: String, limit: Int = 50) -> [FoodSummary] {
        searchIndex.search(text, limit: limit).map { summaries[$0] }
    }

    // MARK: SQLite helpers

    private static func query(_ db: OpaquePointer?, _ sql: String, bind: ((OpaquePointer?) -> Void)? = nil, row: (OpaquePointer?) -> Void) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        bind?(stmt)
        while sqlite3_step(stmt) == SQLITE_ROW { row(stmt) }
    }

    private static func text(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let c = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: c)
    }

    private static func double(_ stmt: OpaquePointer?, _ index: Int32) -> Double? {
        sqlite3_column_type(stmt, index) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, index)
    }
}

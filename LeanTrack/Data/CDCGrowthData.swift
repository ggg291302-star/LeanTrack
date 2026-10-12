import Foundation

/// CDC BMI-for-age reference data for ages 2–20, by sex and month of age.
/// L, M, S: 2000 CDC growth charts (LMS method). sigma and P95: 2022 CDC extended
/// BMI-for-age charts (used above the 95th percentile).
/// Source: https://www.cdc.gov/growthcharts/extended-bmi-data-files.htm (public domain).
struct CDCBMIForAge: Sendable {
    enum Sex: Int, Sendable { case male = 1, female = 2 }

    struct Row: Hashable, Sendable {
        let sex: Sex
        /// Listed at the half-month point: 114.5 covers 114.0 up to (not including) 115.0 months.
        let ageMonths: Double
        let L: Double
        let M: Double
        let S: Double
        let sigma: Double
        let p95: Double
    }

    let rows: [Row]

    static let shared: CDCBMIForAge? = try? CDCBMIForAge()

    init(url: URL? = Bundle.main.url(forResource: "cdc-bmi-for-age-2022", withExtension: "csv", subdirectory: "Data")) throws {
        guard let url else { throw CocoaError(.fileNoSuchFile) }
        try self.init(csv: String(contentsOf: url, encoding: .utf8))
    }

    init(csv: String) throws {
        var lines = csv.split(whereSeparator: \.isNewline).map(String.init)
        guard !lines.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        let header = lines.removeFirst().split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        func column(_ name: String) throws -> Int {
            guard let index = header.firstIndex(of: name) else { throw CocoaError(.fileReadCorruptFile) }
            return index
        }
        let (sex, age, l, m, s, sigma, p95) = try (column("sex"), column("agemos"), column("l"), column("m"), column("s"), column("sigma"), column("p95"))
        rows = lines.compactMap { line in
            let f = line.split(separator: ",", omittingEmptySubsequences: false).map { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard f.count > max(sex, age, l, m, s, sigma, p95),
                  let sexValue = f[sex].flatMap({ Sex(rawValue: Int($0)) }),
                  let ageValue = f[age], let lv = f[l], let mv = f[m], let sv = f[s], let sg = f[sigma], let p = f[p95]
            else { return nil }
            return Row(sex: sexValue, ageMonths: ageValue, L: lv, M: mv, S: sv, sigma: sg, p95: p)
        }
    }

    /// The row for a child's age in months (e.g. 114.3 months → the 114.5 row). Ages 24–240.
    func row(sex: Sex, ageMonths: Double) -> Row? {
        guard ageMonths >= 24, ageMonths < 241 else { return nil }
        let target = ageMonths.rounded(.down) + 0.5
        return rows.first { $0.sex == sex && abs($0.ageMonths - target) < 0.01 }
            ?? rows.filter { $0.sex == sex }.min { abs($0.ageMonths - ageMonths) < abs($1.ageMonths - ageMonths) }
    }
}

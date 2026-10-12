import XCTest
@testable import LeanTrack

/// Checks the bundled CDC file against the worked examples on
/// https://www.cdc.gov/growthcharts/extended-bmi-data-files.htm
final class CDCDataTests: XCTestCase {
    private var data: CDCBMIForAge!

    override func setUpWithError() throws {
        data = try XCTUnwrap(CDCBMIForAge.shared, "cdc-bmi-for-age-2022.csv must be bundled in the app")
    }

    func testCoversBothSexesFromAge2To20() {
        XCTAssertEqual(data.rows.count, 438)
        for sex in [CDCBMIForAge.Sex.male, .female] {
            let ages = data.rows.filter { $0.sex == sex }.map(\.ageMonths)
            XCTAssertEqual(ages.min(), 24)
            XCTAssertEqual(ages.max(), 240.5)
        }
    }

    func testCDCExampleGirl9Years6Months() throws {
        // CDC example 1: girl, 114.5 months.
        let row = try XCTUnwrap(data.row(sex: .female, ageMonths: 114.2))
        XCTAssertEqual(row.ageMonths, 114.5)
        XCTAssertEqual(row.L, -2.257782149, accuracy: 1e-9)
        XCTAssertEqual(row.M, 16.57626713, accuracy: 1e-8)
        XCTAssertEqual(row.S, 0.132796819, accuracy: 1e-9)
        XCTAssertEqual(row.p95, 22.3979, accuracy: 1e-4)
    }

    func testCDCExampleBoy4Years2Months() throws {
        // CDC example 2: boy, 50.5 months.
        let row = try XCTUnwrap(data.row(sex: .male, ageMonths: 50.5))
        XCTAssertEqual(row.p95, 17.8219, accuracy: 1e-4)
        XCTAssertEqual(row.sigma, 2.3983, accuracy: 1e-4)
    }

    func testOutsideAgeRange() {
        XCTAssertNil(data.row(sex: .male, ageMonths: 20))
        XCTAssertNil(data.row(sex: .female, ageMonths: 300))
    }
}

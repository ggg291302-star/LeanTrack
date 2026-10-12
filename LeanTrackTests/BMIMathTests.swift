import XCTest
@testable import LeanTrack

/// BMI categories and CDC percentiles, checked against published values and the CDC method.
final class BMIMathTests: XCTestCase {
    func testAdultCategoriesAtTheCDCCutoffs() {
        XCTAssertEqual(BMIMath.adultCategory(bmi: 18.4), .underweight)
        XCTAssertEqual(BMIMath.adultCategory(bmi: 18.5), .healthy)
        XCTAssertEqual(BMIMath.adultCategory(bmi: 24.9), .healthy)
        XCTAssertEqual(BMIMath.adultCategory(bmi: 24.96), .overweight) // shown as 25.0
        XCTAssertEqual(BMIMath.adultCategory(bmi: 29.9), .overweight)
        XCTAssertEqual(BMIMath.adultCategory(bmi: 30), .obesity1)
        XCTAssertEqual(BMIMath.adultCategory(bmi: 35), .obesity2)
        XCTAssertEqual(BMIMath.adultCategory(bmi: 40), .obesity3)
    }

    func testCDCAdultExample() {
        // CDC: 5 ft 9 in and 160 lb is a BMI of 23.6 (healthy weight).
        let heightCm = UnitConversion.centimeters(feet: 5, inches: 9)
        let kg = UnitConversion.kilograms(fromPounds: 160)
        let bmi = EnergyMath.bmi(weightKg: kg, heightCm: heightCm)
        XCTAssertEqual((bmi * 10).rounded() / 10, 23.6)
        XCTAssertEqual(BMIMath.adultCategory(bmi: bmi), .healthy)
    }

    func testHealthyWeightRange() {
        let range = BMIMath.healthyWeightRange(heightCm: 175)
        XCTAssertEqual(range.lowerBound, 18.5 * 1.75 * 1.75, accuracy: 1e-9)
        XCTAssertEqual(range.upperBound, 24.9 * 1.75 * 1.75, accuracy: 1e-9)
    }

    func testNormalCDF() {
        XCTAssertEqual(BMIMath.normalCDF(0), 0.5, accuracy: 1e-12)
        XCTAssertEqual(BMIMath.normalCDF(1.6448536), 0.95, accuracy: 1e-6)
        XCTAssertEqual(BMIMath.normalCDF(-1.959964), 0.025, accuracy: 1e-6)
    }

    func testLMSPercentiles() throws {
        let data = try XCTUnwrap(CDCBMIForAge.shared)
        let row = try XCTUnwrap(data.row(sex: .female, ageMonths: 114.5))
        // At the median (M) the z-score is 0: the 50th percentile.
        XCTAssertEqual(BMIMath.zScore(bmi: row.M, row: row), 0, accuracy: 1e-12)
        XCTAssertEqual(BMIMath.percentile(bmi: row.M, row: row), 50, accuracy: 1e-9)
        // The CDC's P95 column is the 95th percentile.
        XCTAssertEqual(BMIMath.percentile(bmi: row.p95, row: row), 95, accuracy: 0.1)
    }

    func testExtendedPercentilesAboveP95() throws {
        let data = try XCTUnwrap(CDCBMIForAge.shared)
        let row = try XCTUnwrap(data.row(sex: .male, ageMonths: 50.5))
        // CDC 2022 method: 90 + 10 × Φ((BMI − P95) ÷ sigma). One sigma above P95 → 90 + 10 × 0.8413 = 98.41.
        XCTAssertEqual(BMIMath.percentile(bmi: row.p95 + row.sigma, row: row), 90 + 10 * BMIMath.normalCDF(1), accuracy: 1e-9)
        XCTAssertEqual(BMIMath.percentile(bmi: row.p95 + row.sigma, row: row), 98.41, accuracy: 0.01)
        XCTAssertEqual(BMIMath.childCategory(bmi: row.p95 + 0.1, row: row), .obesity)
        XCTAssertEqual(BMIMath.childCategory(bmi: row.p95 * 1.2, row: row), .severeObesity)
        XCTAssertEqual(BMIMath.childCategory(bmi: row.M, row: row), .healthy)
    }

    func testChildCategoryBoundaries() throws {
        let data = try XCTUnwrap(CDCBMIForAge.shared)
        let row = try XCTUnwrap(data.row(sex: .female, ageMonths: 150))
        func bmi(atPercentile p: Double) -> Double {
            // Inverse LMS: BMI = M × (1 + L × S × z)^(1/L)
            let z = inverseNormal(p / 100)
            return row.M * pow(1 + row.L * row.S * z, 1 / row.L)
        }
        XCTAssertEqual(BMIMath.childCategory(bmi: bmi(atPercentile: 3), row: row), .underweight)
        XCTAssertEqual(BMIMath.childCategory(bmi: bmi(atPercentile: 50), row: row), .healthy)
        XCTAssertEqual(BMIMath.childCategory(bmi: bmi(atPercentile: 90), row: row), .overweight)
        XCTAssertEqual(BMIMath.percentile(bmi: bmi(atPercentile: 90), row: row), 90, accuracy: 0.01)
    }

    func testWaistToHeight() {
        XCTAssertEqual(BMIMath.waistToHeight(waistCm: 85, heightCm: 170), 0.5)
        XCTAssertNil(BMIMath.waistToHeight(waistCm: 0, heightCm: 170))
    }

    func testAgeInMonths() {
        let cal = Calendar(identifier: .gregorian)
        let birth = cal.date(from: DateComponents(year: 2016, month: 1, day: 15))!
        let date = cal.date(from: DateComponents(year: 2025, month: 7, day: 15))!
        XCTAssertEqual(BMIMath.ageInMonths(birthDate: birth, on: date, calendar: cal), 114, accuracy: 0.01)
    }

    /// Acklam's approximation, good to about 1e-9, only used to build test inputs.
    private func inverseNormal(_ p: Double) -> Double {
        let a = [-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02, 1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00]
        let b = [-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02, 6.680131188771972e+01, -1.328068155288572e+01]
        let c = [-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00, -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00]
        let d = [7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00, 3.754408661907416e+00]
        let low = 0.02425
        if p < low {
            let q = (-2 * log(p)).squareRoot()
            return (((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        }
        if p > 1 - low {
            let q = (-2 * log(1 - p)).squareRoot()
            return -(((((c[0] * q + c[1]) * q + c[2]) * q + c[3]) * q + c[4]) * q + c[5]) / ((((d[0] * q + d[1]) * q + d[2]) * q + d[3]) * q + 1)
        }
        let q = p - 0.5, r = q * q
        return (((((a[0] * r + a[1]) * r + a[2]) * r + a[3]) * r + a[4]) * r + a[5]) * q / (((((b[0] * r + b[1]) * r + b[2]) * r + b[3]) * r + b[4]) * r + 1)
    }
}

import Foundation

/// BMI categories and percentiles.
/// - Adults (20+): CDC / WHO categories. https://www.cdc.gov/bmi/adult-calculator/bmi-categories.html
/// - Ages 2–19: CDC BMI-for-age percentiles. Up to the 95th percentile they come from the 2000 CDC
///   growth charts (LMS method); above it, from the 2022 CDC extended BMI-for-age method:
///   percentile = 90 + 10 × Φ((BMI − P95) ÷ sigma). https://www.cdc.gov/growthcharts/extended-bmi.htm
/// - Waist-to-height ratio: 0.5 or more means increased health risk (NICE guideline NG246).
enum BMIMath {
    enum AdultCategory: String, CaseIterable, Sendable {
        case underweight, healthy, overweight, obesity1, obesity2, obesity3

        var title: String {
            switch self {
            case .underweight: "Underweight"
            case .healthy: "Healthy weight"
            case .overweight: "Overweight"
            case .obesity1: "Obesity (class 1)"
            case .obesity2: "Obesity (class 2)"
            case .obesity3: "Obesity (class 3, severe)"
            }
        }

        var range: String {
            switch self {
            case .underweight: "below 18.5"
            case .healthy: "18.5 to 24.9"
            case .overweight: "25.0 to 29.9"
            case .obesity1: "30.0 to 34.9"
            case .obesity2: "35.0 to 39.9"
            case .obesity3: "40.0 or more"
            }
        }
    }

    enum ChildCategory: String, Sendable {
        case underweight, healthy, overweight, obesity, severeObesity

        var title: String {
            switch self {
            case .underweight: "Underweight"
            case .healthy: "Healthy weight"
            case .overweight: "Overweight"
            case .obesity: "Obesity"
            case .severeObesity: "Severe obesity"
            }
        }

        var range: String {
            switch self {
            case .underweight: "below the 5th percentile"
            case .healthy: "5th to below the 85th percentile"
            case .overweight: "85th to below the 95th percentile"
            case .obesity: "95th percentile or above"
            case .severeObesity: "120% of the 95th percentile or above"
            }
        }
    }

    /// CDC adult categories. BMI is rounded to one decimal first, like the CDC calculator.
    static func adultCategory(bmi: Double) -> AdultCategory {
        let b = (bmi * 10).rounded() / 10
        switch b {
        case ..<18.5: return .underweight
        case ..<25: return .healthy
        case ..<30: return .overweight
        case ..<35: return .obesity1
        case ..<40: return .obesity2
        default: return .obesity3
        }
    }

    /// Weights (kg) that give a BMI of 18.5 to 24.9 at this height.
    static func healthyWeightRange(heightCm: Double) -> ClosedRange<Double> {
        let m = heightCm / 100
        return (18.5 * m * m)...(24.9 * m * m)
    }

    /// Standard normal cumulative distribution Φ(z).
    static func normalCDF(_ z: Double) -> Double {
        0.5 * erfc(-z / 2.0.squareRoot())
    }

    /// LMS z-score: ((BMI ÷ M)^L − 1) ÷ (L × S), or ln(BMI ÷ M) ÷ S when L is 0.
    static func zScore(bmi: Double, row: CDCBMIForAge.Row) -> Double {
        if abs(row.L) < 1e-12 { return log(bmi / row.M) / row.S }
        return (pow(bmi / row.M, row.L) - 1) / (row.L * row.S)
    }

    /// BMI-for-age percentile (0–100), using the extended method above the 95th percentile.
    static func percentile(bmi: Double, row: CDCBMIForAge.Row) -> Double {
        if bmi > row.p95 {
            return 90 + 10 * normalCDF((bmi - row.p95) / row.sigma)
        }
        return normalCDF(zScore(bmi: bmi, row: row)) * 100
    }

    /// BMI as a percent of the 95th percentile (120% or more = severe obesity).
    static func percentOfP95(bmi: Double, row: CDCBMIForAge.Row) -> Double {
        bmi / row.p95 * 100
    }

    static func childCategory(bmi: Double, row: CDCBMIForAge.Row) -> ChildCategory {
        let p = percentile(bmi: bmi, row: row)
        if percentOfP95(bmi: bmi, row: row) >= 120 { return .severeObesity }
        switch p {
        case ..<5: return .underweight
        case ..<85: return .healthy
        case ..<95: return .overweight
        default: return .obesity
        }
    }

    /// Age in whole months between two dates.
    static func ageInMonths(birthDate: Date, on date: Date = .now, calendar: Calendar = .current) -> Double {
        let c = calendar.dateComponents([.month, .day], from: birthDate, to: date)
        return Double(c.month ?? 0) + Double(c.day ?? 0) / 30.4375
    }

    static func waistToHeight(waistCm: Double, heightCm: Double) -> Double? {
        guard waistCm > 0, heightCm > 0 else { return nil }
        return waistCm / heightCm
    }
}

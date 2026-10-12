import Foundation

/// Exact unit definitions (NIST Handbook 44, Appendix C; the 1959 international
/// yard and pound agreement). Every conversion in the app goes through here.
enum UnitConversion {
    static let kilogramsPerPound = 0.45359237
    static let gramsPerOunce = 28.349523125
    static let centimetersPerInch = 2.54
    static let inchesPerFoot = 12.0
    static let millilitersPerUSFluidOunce = 29.5735295625

    // MARK: Weight

    static func kilograms(fromPounds pounds: Double) -> Double {
        pounds * kilogramsPerPound
    }

    static func pounds(fromKilograms kilograms: Double) -> Double {
        kilograms / kilogramsPerPound
    }

    static func grams(fromOunces ounces: Double) -> Double {
        ounces * gramsPerOunce
    }

    static func ounces(fromGrams grams: Double) -> Double {
        grams / gramsPerOunce
    }

    // MARK: Length

    static func centimeters(fromInches inches: Double) -> Double {
        inches * centimetersPerInch
    }

    static func inches(fromCentimeters centimeters: Double) -> Double {
        centimeters / centimetersPerInch
    }

    static func centimeters(feet: Int, inches: Double) -> Double {
        centimeters(fromInches: Double(feet) * inchesPerFoot + inches)
    }

    /// Splits a height into whole feet and leftover inches (rounded to 0.1 in),
    /// carrying 12.0 in over to the next foot.
    static func feetAndInches(fromCentimeters centimeters: Double) -> (feet: Int, inches: Double) {
        let totalInches = (inches(fromCentimeters: centimeters) * 10).rounded() / 10
        var feet = Int(totalInches / inchesPerFoot)
        var rest = ((totalInches - Double(feet) * inchesPerFoot) * 10).rounded() / 10
        if rest >= inchesPerFoot {
            feet += 1
            rest -= inchesPerFoot
        }
        return (feet, rest)
    }

    // MARK: Volume

    static func milliliters(fromFluidOunces fluidOunces: Double) -> Double {
        fluidOunces * millilitersPerUSFluidOunce
    }

    static func fluidOunces(fromMilliliters milliliters: Double) -> Double {
        milliliters / millilitersPerUSFluidOunce
    }
}

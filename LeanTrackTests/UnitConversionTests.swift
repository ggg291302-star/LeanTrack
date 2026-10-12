import XCTest
@testable import LeanTrack

/// Checks against the exact definitions in NIST Handbook 44, Appendix C.
final class UnitConversionTests: XCTestCase {
    func testPoundsAndKilograms() {
        XCTAssertEqual(UnitConversion.kilograms(fromPounds: 1), 0.45359237, accuracy: 1e-12)
        XCTAssertEqual(UnitConversion.kilograms(fromPounds: 180), 81.6466266, accuracy: 1e-7)
        XCTAssertEqual(UnitConversion.pounds(fromKilograms: 100), 220.4622622, accuracy: 1e-6)
        XCTAssertEqual(UnitConversion.pounds(fromKilograms: UnitConversion.kilograms(fromPounds: 172.4)), 172.4, accuracy: 1e-9)
    }

    func testOuncesAndGrams() {
        XCTAssertEqual(UnitConversion.grams(fromOunces: 1), 28.349523125, accuracy: 1e-12)
        XCTAssertEqual(UnitConversion.grams(fromOunces: 16), 453.59237, accuracy: 1e-9) // 16 oz = 1 lb
        XCTAssertEqual(UnitConversion.ounces(fromGrams: 100), 3.5273962, accuracy: 1e-7)
    }

    func testHeight() {
        XCTAssertEqual(UnitConversion.centimeters(fromInches: 1), 2.54, accuracy: 1e-12)
        XCTAssertEqual(UnitConversion.centimeters(feet: 5, inches: 10), 177.8, accuracy: 1e-9)
        XCTAssertEqual(UnitConversion.centimeters(feet: 6, inches: 0), 182.88, accuracy: 1e-9)

        let fiveTen = UnitConversion.feetAndInches(fromCentimeters: 177.8)
        XCTAssertEqual(fiveTen.feet, 5)
        XCTAssertEqual(fiveTen.inches, 10, accuracy: 1e-9)

        // 182.87 cm is 71.996 in, which rounds to 72.0 in, so it must read 6 ft 0 in (not 5 ft 12 in).
        let six = UnitConversion.feetAndInches(fromCentimeters: 182.87)
        XCTAssertEqual(six.feet, 6)
        XCTAssertEqual(six.inches, 0, accuracy: 1e-9)
    }

    func testFluidOunces() {
        XCTAssertEqual(UnitConversion.milliliters(fromFluidOunces: 1), 29.5735295625, accuracy: 1e-12)
        XCTAssertEqual(UnitConversion.milliliters(fromFluidOunces: 8), 236.5882365, accuracy: 1e-9) // 1 US cup
        XCTAssertEqual(UnitConversion.fluidOunces(fromMilliliters: 500), 16.9070114, accuracy: 1e-6)
    }
}

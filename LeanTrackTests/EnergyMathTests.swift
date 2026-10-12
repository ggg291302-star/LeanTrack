import XCTest
@testable import LeanTrack

/// Worked examples for the Mifflin-St Jeor equation and the safety guardrails.
final class EnergyMathTests: XCTestCase {
    func testMifflinStJeorWorkedExamples() {
        // Woman, 30, 70 kg, 165 cm: 10×70 + 6.25×165 − 5×30 − 161 = 1,420.25
        XCTAssertEqual(EnergyMath.bmr(sex: .female, weightKg: 70, heightCm: 165, age: 30), 1420.25, accuracy: 1e-9)
        // Man, 25, 80 kg, 180 cm: 10×80 + 6.25×180 − 5×25 + 5 = 1,805
        XCTAssertEqual(EnergyMath.bmr(sex: .male, weightKg: 80, heightCm: 180, age: 25), 1805, accuracy: 1e-9)
    }

    func testActivityMultipliers() {
        XCTAssertEqual(EnergyMath.tdee(bmr: 1805, activity: .moderate), 2797.75, accuracy: 1e-9)
        XCTAssertEqual(ActivityLevel.allCases.map(\.multiplier), [1.2, 1.375, 1.55, 1.725, 1.9])
    }

    func testOnePoundAWeekIs500CaloriesADay() {
        let plan = EnergyMath.plan(sex: .male, age: 25, weightKg: 80, heightCm: 180, activity: .moderate, goal: .lose,
                                   paceLbPerWeek: 1, goalWeightKg: 75, pregnantOrBreastfeeding: false)
        XCTAssertEqual(plan.calories, 2300) // 2,797.75 − 500 = 2,297.75 → nearest 10
        XCTAssertEqual(plan.paceLbPerWeek, 1)
        XCTAssertTrue(plan.notes.isEmpty)
    }

    func testPaceCappedAtOnePercentAndCaloriesRaisedToFloor() {
        // 55 kg = 121.25 lb, so the fastest suggested pace is 1.21 lb a week.
        let plan = EnergyMath.plan(sex: .female, age: 30, weightKg: 55, heightCm: 160, activity: .sedentary, goal: .lose,
                                   paceLbPerWeek: 2, goalWeightKg: 50, pregnantOrBreastfeeding: false)
        XCTAssertEqual(plan.paceLbPerWeek, UnitConversion.pounds(fromKilograms: 55) * 0.01, accuracy: 1e-9)
        XCTAssertEqual(plan.calories, 1200)
        XCTAssertTrue(plan.notes.contains(.raisedToFloor(floor: 1200)))
        XCTAssertTrue(plan.notes.contains { if case .paceReduced = $0 { true } else { false } })
    }

    func testMaleFloorIs1500() {
        XCTAssertEqual(EnergyMath.calorieFloor(sex: .male), 1500)
        XCTAssertEqual(EnergyMath.calorieFloor(sex: .female), 1200)
        XCTAssertEqual(EnergyMath.maxLossLbPerWeek(weightKg: 150), 2) // 1% of 330 lb is more than 2 lb
    }

    func testNoLossPlanUnder18OrPregnant() {
        let teen = EnergyMath.plan(sex: .female, age: 16, weightKg: 70, heightCm: 165, activity: .light, goal: .lose,
                                   paceLbPerWeek: 1, goalWeightKg: 60, pregnantOrBreastfeeding: false)
        XCTAssertTrue(teen.notes.contains(.noLossPlanUnder18))
        XCTAssertEqual(teen.paceLbPerWeek, 0)
        XCTAssertEqual(Double(teen.calories), (teen.tdee / 10).rounded() * 10, accuracy: 0.001)

        let pregnant = EnergyMath.plan(sex: .female, age: 30, weightKg: 70, heightCm: 165, activity: .light, goal: .lose,
                                       paceLbPerWeek: 1, goalWeightKg: 60, pregnantOrBreastfeeding: true)
        XCTAssertTrue(pregnant.notes.contains(.noLossPlanPregnancy))
        XCTAssertEqual(pregnant.paceLbPerWeek, 0)
    }

    func testWarnsWhenGoalBMIIsUnderweight() {
        // 48 kg at 165 cm is a BMI of 17.6.
        let plan = EnergyMath.plan(sex: .female, age: 30, weightKg: 60, heightCm: 165, activity: .light, goal: .lose,
                                   paceLbPerWeek: 0.5, goalWeightKg: 48, pregnantOrBreastfeeding: false)
        XCTAssertTrue(plan.notes.contains { if case .goalBMIUnderweight = $0 { true } else { false } })
    }

    func testGainPaceCappedAtHalfAPound() {
        let plan = EnergyMath.plan(sex: .male, age: 25, weightKg: 70, heightCm: 180, activity: .moderate, goal: .gain,
                                   paceLbPerWeek: 1, goalWeightKg: 75, pregnantOrBreastfeeding: false)
        XCTAssertEqual(plan.paceLbPerWeek, 0.5)
        XCTAssertEqual(Double(plan.calories), ((plan.tdee + 250) / 10).rounded() * 10, accuracy: 0.001)
    }

    func testManualGoalWarnings() {
        XCTAssertFalse(EnergyMath.manualGoalWarnings(calories: 1000, sex: .female).isEmpty)
        XCTAssertTrue(EnergyMath.manualGoalWarnings(calories: 1300, sex: .female).isEmpty)
        XCTAssertFalse(EnergyMath.manualGoalWarnings(calories: 1400, sex: .male).isEmpty)
    }

    func testMacroGramsFromPercents() {
        let g = MacroGrams.fromPercents(calories: 2000, protein: 20, carbs: 50, fat: 30)
        XCTAssertEqual(g.protein, 100, accuracy: 1e-9)
        XCTAssertEqual(g.carbs, 250, accuracy: 1e-9)
        XCTAssertEqual(g.fat, 2000 * 0.3 / 9, accuracy: 1e-9)
        for preset in MacroPreset.allCases {
            if let p = preset.percents { XCTAssertEqual(p.protein + p.carbs + p.fat, 100, "\(preset)") }
        }
    }

    func testBMIFormula() {
        XCTAssertEqual(EnergyMath.bmi(weightKg: 70, heightCm: 175), 70 / (1.75 * 1.75), accuracy: 1e-12)
    }
}

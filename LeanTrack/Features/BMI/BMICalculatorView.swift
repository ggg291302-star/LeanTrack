import SwiftUI
import SwiftData
import Charts

/// More → BMI Calculator. Starts with the profile's numbers; every field can be changed
/// (to check someone else, like a child). Nothing here changes the profile except the waist size.
struct BMICalculatorView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date) private var weighIns: [WeightEntry]
    @State private var sex: Sex = .female
    @State private var birthDate = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    @State private var heightCm = 170.0
    @State private var weightKg = 70.0
    @State private var waistCm: Double = 0
    @State private var activity: ActivityLevel = .light
    @State private var loaded = false

    private var weightUnit: WeightUnit { profiles.first?.weightUnit ?? .lb }
    private var heightUnit: HeightUnit { profiles.first?.heightUnit ?? .feetInches }

    var body: some View {
        let bmi = EnergyMath.bmi(weightKg: weightKg, heightCm: heightCm)
        let ageMonths = BMIMath.ageInMonths(birthDate: birthDate)
        let ageYears = Int(ageMonths / 12)
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                inputs
                if heightCm >= 50 && weightKg >= 2 {
                    if ageMonths < 24 {
                        NoteCard(text: "BMI isn't used for children under 2. For babies and toddlers, the CDC recommends the WHO weight-for-length growth charts. Ask your child's doctor.")
                    } else if ageMonths < 240 {
                        childResult(bmi: bmi, ageMonths: ageMonths)
                    } else {
                        adultResult(bmi: bmi)
                    }
                    if ageYears >= 18 { energyCard }
                    waistCard
                    if ageMonths >= 240 { historyCard }
                }
                aboutCard
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .navigationTitle("BMI Calculator")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Use My Profile") { loadProfile() }.font(.subheadline)
            }
        }
        .onAppear { if !loaded { loadProfile(); loaded = true } }
        .onChange(of: waistCm) { _, value in
            if let p = profiles.first, abs(p.waistCm - value) > 0.01 { p.waistCm = value; try? context.save() }
        }
    }

    private func loadProfile() {
        guard let p = profiles.first else { return }
        sex = p.sex; birthDate = p.birthDate; heightCm = p.heightCm; weightKg = p.currentWeightKg
        waistCm = p.waistCm; activity = p.activity
    }

    // MARK: Inputs

    private var inputs: some View {
        LTCard {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Sex", selection: $sex) { ForEach(Sex.allCases) { Text($0.title).tag($0) } }
                    .pickerStyle(.segmented)
                DatePicker("Birthday", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
                    .foregroundStyle(Theme.textPrimary)
                Divider()
                HeightField(heightCm: $heightCm, unit: heightUnit)
                Divider()
                WeightField(title: "Weight", kg: $weightKg, unit: weightUnit)
                    .accessibilityIdentifier("bmi.weight")
            }
        }
    }

    // MARK: Results

    private func adultResult(bmi: Double, compact: Bool = false) -> some View {
        let category = BMIMath.adultCategory(bmi: bmi)
        let healthy = BMIMath.healthyWeightRange(heightCm: heightCm)
        return LTCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Format.number(bmi, decimals: 1))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .accessibilityIdentifier("bmi.value")
                    Text("BMI").foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text(category.title).font(.headline).foregroundStyle(color(for: category))
                        .accessibilityIdentifier("bmi.category")
                }
                BMIGauge(bmi: bmi)
                Text("Adult categories (CDC): \(category.title) is a BMI of \(category.range).")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                Divider()
                Text("Healthy weight for your height: \(Format.weight(kg: healthy.lowerBound, unit: weightUnit, decimals: 0)) to \(Format.weight(kg: healthy.upperBound, unit: weightUnit, decimals: 0)) (BMI 18.5–24.9).")
                    .font(.subheadline).foregroundStyle(Theme.textPrimary)
                if weightKg > healthy.upperBound {
                    Text("That's \(Format.weight(kg: weightKg - healthy.upperBound, unit: weightUnit)) above the top of the range.")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                } else if weightKg < healthy.lowerBound {
                    Text("That's \(Format.weight(kg: healthy.lowerBound - weightKg, unit: weightUnit)) below the bottom of the range.")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func childResult(bmi: Double, ageMonths: Double) -> some View {
        let cdcSex: CDCBMIForAge.Sex = sex == .male ? .male : .female
        if let row = CDCBMIForAge.shared?.row(sex: cdcSex, ageMonths: ageMonths) {
            let percentile = BMIMath.percentile(bmi: bmi, row: row)
            let category = BMIMath.childCategory(bmi: bmi, row: row)
            LTCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Format.number(bmi, decimals: 1)).font(.system(size: 44, weight: .bold, design: .rounded)).foregroundStyle(Theme.textPrimary)
                        Text("BMI").foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Text(category.title).font(.headline).foregroundStyle(category == .healthy ? Theme.positive : Theme.fat)
                    }
                    Text("\(percentileText(percentile)) percentile for a \(Int(ageMonths / 12))-year-old \(sex == .male ? "boy" : "girl")")
                        .font(.title3.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                        .accessibilityIdentifier("bmi.percentile")
                    Text("For ages 2–19, BMI is compared with children of the same age and sex using the CDC growth charts. \(category.title) means \(category.range).")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    if percentile >= 95 {
                        Text("BMI is \(Format.number(BMIMath.percentOfP95(bmi: bmi, row: row)))% of the 95th percentile (CDC 2022 extended BMI-for-age charts).")
                            .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    }
                    Text("Only a doctor can say whether a child's weight is a health concern. LeanTrack doesn't make weight-loss plans for anyone under 18.")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private func percentileText(_ p: Double) -> String {
        if p >= 99.95 { return ">99.9th" }
        if p > 97 { return Format.number(p, decimals: 1) + "th" }
        let n = Int(p.rounded())
        let suffix: String
        switch (n % 100, n % 10) {
        case (11...13, _): suffix = "th"
        case (_, 1): suffix = "st"
        case (_, 2): suffix = "nd"
        case (_, 3): suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }

    private func color(for category: BMIMath.AdultCategory) -> Color {
        switch category {
        case .underweight: Theme.carbs
        case .healthy: Theme.positive
        case .overweight: Theme.fat
        default: Theme.danger
        }
    }

    private var energyCard: some View {
        let age = Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 0
        let bmr = EnergyMath.bmr(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age)
        return LTCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Energy").font(.headline).foregroundStyle(Theme.textPrimary)
                HStack {
                    Text("Resting burn (BMR)").foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(Format.calories(bmr)) cal/day").foregroundStyle(Theme.textPrimary).monospacedDigit()
                }
                Picker("Activity", selection: $activity) { ForEach(ActivityLevel.allCases) { Text($0.title).tag($0) } }
                    .foregroundStyle(Theme.textPrimary)
                HStack {
                    Text("Total daily burn (TDEE)").foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(Format.calories(EnergyMath.tdee(bmr: bmr, activity: activity))) cal/day").foregroundStyle(Theme.textPrimary).monospacedDigit()
                }
                Text("Mifflin-St Jeor equation × activity factor. An estimate: real needs vary by a few hundred calories.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private var waistCard: some View {
        let ratio = BMIMath.waistToHeight(waistCm: waistCm, heightCm: heightCm)
        let metric = heightUnit == .cm
        return LTCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Waist-to-height ratio").font(.headline).foregroundStyle(Theme.textPrimary)
                LabeledField("Waist (optional)") {
                    NumberField(placeholder: metric ? "cm" : "in", value: Binding(
                        get: { metric ? waistCm : (UnitConversion.inches(fromCentimeters: waistCm) * 10).rounded() / 10 },
                        set: { waistCm = metric ? max(0, $0) : UnitConversion.centimeters(fromInches: max(0, $0)) }
                    ), unit: metric ? "cm" : "in")
                }
                if let ratio {
                    Text("Ratio: \(Format.number(ratio, decimals: 2))").font(.title3.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                    Text(ratio >= 0.6 ? "0.6 or more: high health risk from central fat."
                         : ratio >= 0.5 ? "0.5 to 0.59: increased health risk from central fat."
                         : ratio >= 0.4 ? "0.4 to 0.49: no increased risk from central fat."
                         : "Below 0.4. If you're concerned about being underweight, talk to a doctor.")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                } else {
                    Text("Measure around your waist, midway between your lowest rib and the top of your hip bone, after breathing out. Keeping your waist under half your height is a simple target (NICE guideline NG246).")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private var historyCard: some View {
        if weighIns.count >= 2, let height = profiles.first?.heightCm {
            LTCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("BMI history").font(.headline).foregroundStyle(Theme.textPrimary)
                    let values = weighIns.enumerated().map { BMIPoint(index: $0.offset, date: $0.element.date, bmi: EnergyMath.bmi(weightKg: $0.element.weightKg, heightCm: height)) }
                    let lower = min(18, (values.map(\.bmi).min() ?? 18) - 1)
                    let upper = max(26, (values.map(\.bmi).max() ?? 26) + 1)
                    Chart {
                        RuleMark(y: .value("Healthy low", 18.5))
                            .foregroundStyle(Theme.positive.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        RuleMark(y: .value("Healthy high", 24.9))
                            .foregroundStyle(Theme.positive.opacity(0.6))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        ForEach(values) { v in
                            LineMark(x: .value("Date", v.date), y: .value("BMI", v.bmi)).foregroundStyle(Theme.accent).symbol(Circle())
                        }
                    }
                    .chartYScale(domain: lower...upper)
                    .frame(height: 170)
                    Text("From your weigh-ins and the height in your profile. The green dashed lines mark the healthy range (18.5–24.9).")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var aboutCard: some View {
        LTCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("About BMI").font(.headline).foregroundStyle(Theme.textPrimary)
                Text("BMI (weight in kg ÷ height in m²) is a quick screening number, not a diagnosis. It doesn't tell muscle from fat, and the same BMI can mean different things for athletes, older adults, and people of different ethnic backgrounds. Talk to a doctor about what's healthy for you.")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                Link("CDC: Adult BMI categories", destination: URL(string: "https://www.cdc.gov/bmi/adult-calculator/bmi-categories.html")!)
                Link("CDC: Child and teen BMI categories", destination: URL(string: "https://www.cdc.gov/bmi/child-teen-calculator/bmi-categories.html")!)
                Link("CDC: Extended BMI-for-age growth charts", destination: URL(string: "https://www.cdc.gov/growthcharts/extended-bmi.htm")!)
                Link("WHO: Obesity and overweight", destination: URL(string: "https://www.who.int/news-room/fact-sheets/detail/obesity-and-overweight")!)
                Link("NIH NHLBI: Assessing your weight", destination: URL(string: "https://www.nhlbi.nih.gov/health/educational/lose_wt/BMI/bmicalc.htm")!)
            }
            .font(.subheadline)
        }
    }
}

private struct BMIPoint: Identifiable {
    let index: Int
    let date: Date
    let bmi: Double
    var id: Int { index }
}

/// Colored BMI scale from 15 to 40 with a marker.
struct BMIGauge: View {
    let bmi: Double
    private let low = 15.0, high = 40.0
    private let bands: [(from: Double, to: Double, color: Color)] = [
        (15, 18.5, Theme.carbs), (18.5, 25, Theme.positive), (25, 30, Theme.fat), (30, 40, Theme.danger),
    ]

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    HStack(spacing: 2) {
                        ForEach(Array(bands.enumerated()), id: \.offset) { _, band in
                            band.color.frame(width: max(0, (band.to - band.from) / (high - low) * w - 2))
                        }
                    }
                    .frame(height: 10)
                    .clipShape(Capsule())
                    let x = (min(max(bmi, low), high) - low) / (high - low) * w
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(Color.black.opacity(0.4), lineWidth: 1))
                        .frame(width: 18, height: 18)
                        .offset(x: x - 9)
                }
            }
            .frame(height: 18)
            HStack {
                ForEach(["15", "18.5", "25", "30", "40"], id: \.self) { label in
                    Text(label).font(.caption2).foregroundStyle(Theme.textSecondary)
                    if label != "40" { Spacer() }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("BMI scale with your BMI of \(Format.number(bmi, decimals: 1)) marked")
    }
}

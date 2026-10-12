import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// More → Settings.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @AppStorage("appearance") private var appearance = Appearance.dark.rawValue
    @State private var confirmErase = false
    @State private var confirmEraseAgain = false
    @State private var alsoRemoveKeys = false

    var body: some View {
        let profile = profiles.first
        List {
            Section {
                link("person.crop.circle", "Account") { ProfileSettingsView() }
                link("target", "Nutrition Goals") { GoalsView() }
                link("bell", "Notifications") { NotificationsSettingsView() }
                link("ruler", "Units", value: profile.map { "\($0.weightUnit.rawValue), \($0.foodUnit.title)" }) { UnitsSettingsView() }
                Picker(selection: $appearance) {
                    ForEach(Appearance.allCases) { Text($0.title).tag($0.rawValue) }
                } label: {
                    Label("Appearance", systemImage: "circle.lefthalf.filled")
                }
                .accessibilityIdentifier("settings.appearance")
            }
            .listRowBackground(Theme.card)

            Section {
                link("externaldrive", "Food Database", value: KeychainStore.has(.usdaAPIKey) ? "Own key" : nil) { FoodDatabaseSettingsView() }
                link("sparkles", "AI Photo Estimates", value: KeychainStore.has(.anthropicAPIKey) ? "On" : "Off") { AIPhotoSettingsView() }
                link("arrow.up.doc", "Backup & Restore") { BackupView() }
            }
            .listRowBackground(Theme.card)

            Section {
                link("questionmark.circle", "Help & Support") { HelpView() }
                link("info.circle", "About") { AboutView() }
            }
            .listRowBackground(Theme.card)

            Section {
                Button("Erase All Data", role: .destructive) { confirmErase = true }
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("settings.erase")
            } footer: {
                Text("There's no account to log out of: everything is stored only on this iPhone.")
            }
            .listRowBackground(Theme.card)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Erase all data?", isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Erase everything", role: .destructive) { alsoRemoveKeys = false; confirmEraseAgain = true }
            Button("Erase everything and my API keys", role: .destructive) { alsoRemoveKeys = true; confirmEraseAgain = true }
        } message: {
            Text("This deletes your profile, diary, weigh-ins, water, custom foods, meals, recipes and favorites from this iPhone. Make a backup first if you might want them back.")
        }
        .alert("Are you sure?", isPresented: $confirmEraseAgain) {
            Button("Erase", role: .destructive) { erase() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }

    private func link<Destination: View>(_ icon: String, _ title: String, value: String? = nil,
                                         @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Label(title, systemImage: icon).foregroundStyle(Theme.textPrimary)
                Spacer()
                if let value { Text(value).foregroundStyle(Theme.textSecondary) }
            }
        }
        .accessibilityIdentifier("settings.\(title)")
    }

    private func erase() {
        try? BackupService.eraseAll(in: context)
        NotificationService.turnAllOff()
        if alsoRemoveKeys { KeychainStore.removeAll() }
    }
}

// MARK: - Account

struct ProfileSettingsView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        Group {
            if let profile = profiles.first { ProfileForm(profile: profile) }
        }
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ProfileForm: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            Section("You") {
                TextField("Name (optional)", text: $profile.name)
                Picker("Sex", selection: Binding(get: { profile.sex }, set: { profile.sex = $0; update() })) {
                    ForEach(Sex.allCases) { Text($0.title).tag($0) }
                }
                DatePicker("Birthday", selection: Binding(get: { profile.birthDate }, set: { profile.birthDate = $0; update() }),
                           in: ...Date.now, displayedComponents: .date)
                HeightField(heightCm: Binding(get: { profile.heightCm }, set: { profile.heightCm = $0; update() }), unit: profile.heightUnit)
                if profile.sex == .female {
                    Toggle("Pregnant or breastfeeding", isOn: Binding(get: { profile.pregnantOrBreastfeeding }, set: { profile.pregnantOrBreastfeeding = $0; update() }))
                }
            }
            Section {
                NavigationLink { WeighInsView() } label: {
                    LabeledContent("Current weight", value: Format.weight(kg: profile.currentWeightKg, unit: profile.weightUnit))
                }
                WeightField(title: "Starting weight", kg: $profile.startWeightKg, unit: profile.weightUnit)
            } header: { Text("Weight") } footer: {
                Text("Your current weight is your latest weigh-in. Log a new one from Progress or Weigh-ins.")
            }
            Section {
                LabeledContent("Age", value: "\(profile.age())")
                LabeledContent("BMI", value: Format.number(profile.bmi, decimals: 1))
                LabeledContent("Daily calorie goal", value: profile.calorieGoal.formatted())
            }
        }
        .onDisappear { try? context.save() }
    }

    private func update() {
        profile.applyRecommendedCalories()
        try? context.save()
    }
}

// MARK: - Units

struct UnitsSettingsView: View {
    @Query private var profiles: [UserProfile]

    var body: some View {
        Group {
            if let profile = profiles.first { UnitsForm(profile: profile) }
        }
        .navigationTitle("Units")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct UnitsForm: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            Picker("Body weight", selection: $profile.weightUnitRaw) {
                ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            Picker("Height", selection: $profile.heightUnitRaw) {
                ForEach(HeightUnit.allCases) { Text($0.title).tag($0.rawValue) }
            }
            Picker("Food amounts", selection: $profile.foodUnitRaw) {
                ForEach(FoodUnit.allCases) { Text($0.title).tag($0.rawValue) }
            }
            Picker("Water", selection: $profile.volumeUnitRaw) {
                ForEach(VolumeUnit.allCases) { Text($0.title).tag($0.rawValue) }
            }
            Section {
                Text("Everything is stored in metric and converted for display with exact NIST factors, so switching units never changes your data.")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .onDisappear { try? context.save() }
    }
}

// MARK: - Notifications

struct NotificationsSettingsView: View {
    @State private var enabled: [Reminder: Bool] = [:]
    @State private var times: [Reminder: Date] = [:]
    @State private var denied = false

    var body: some View {
        Form {
            Section {
                ForEach(Reminder.allCases) { reminder in
                    Toggle(isOn: Binding(get: { enabled[reminder] ?? false }, set: { on in toggle(reminder, on) })) {
                        Text(reminder == .water ? "Water (every 2 hours)" : reminder.title)
                    }
                    if enabled[reminder] ?? false {
                        DatePicker(reminder == .water ? "Starting at" : "Time", selection: Binding(
                            get: { times[reminder] ?? date(minutes: reminder.minutes) },
                            set: { setTime(reminder, $0) }
                        ), displayedComponents: .hourAndMinute)
                    }
                }
            } footer: {
                Text("Reminders are local to this iPhone. They're all off until you turn them on.")
            }
            if denied {
                Section {
                    Text("Notifications are turned off for LeanTrack in iOS Settings.").foregroundStyle(Theme.fat)
                    if let url = URL(string: UIApplication.openSettingsURLString) { Link("Open Settings", destination: url) }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            for r in Reminder.allCases {
                enabled[r] = r.isEnabled
                times[r] = date(minutes: r.minutes)
            }
        }
    }

    private func date(minutes: Int) -> Date {
        Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
    }

    private func toggle(_ reminder: Reminder, _ on: Bool) {
        enabled[reminder] = on
        UserDefaults.standard.set(on, forKey: reminder.enabledKey)
        Task {
            if on {
                let allowed = await NotificationService.requestAuthorization()
                denied = !allowed
            }
            NotificationService.reschedule()
        }
    }

    private func setTime(_ reminder: Reminder, _ value: Date) {
        times[reminder] = value
        let c = Calendar.current.dateComponents([.hour, .minute], from: value)
        UserDefaults.standard.set((c.hour ?? 0) * 60 + (c.minute ?? 0), forKey: reminder.timeKey)
        NotificationService.reschedule()
    }
}

// MARK: - Food database

struct FoodDatabaseSettingsView: View {
    @AppStorage("openFoodFactsEnabled") private var openFoodFactsEnabled = true
    @State private var keyText = ""
    @State private var hasKey = KeychainStore.has(.usdaAPIKey)
    @State private var message: String?

    var body: some View {
        let db = FoodDatabase.shared
        Form {
            Section {
                LabeledContent("Foods", value: (db?.foodCount ?? 0).formatted())
                LabeledContent("Built", value: db?.meta["built"] ?? "—")
                ForEach(["F", "S", "N"], id: \.self) { code in
                    if let source = db?.meta["source.\(code)"] {
                        Text(source).font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
            } header: { Text("Built-in USDA database (works offline)") }

            Section {
                if hasKey {
                    Label("Your own key is saved in the iOS Keychain.", systemImage: "checkmark.seal.fill").foregroundStyle(Theme.positive)
                    Button("Remove Key", role: .destructive) {
                        KeychainStore.set(nil, for: .usdaAPIKey)
                        hasKey = false
                        message = "Removed. LeanTrack uses the shared DEMO_KEY again."
                    }
                } else {
                    SecureField("Paste your api.data.gov key", text: $keyText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("settings.usdaKey")
                    Button("Save Key") {
                        if KeychainStore.set(keyText, for: .usdaAPIKey) {
                            hasKey = KeychainStore.has(.usdaAPIKey)
                            keyText = ""
                            message = "Saved in the Keychain."
                        } else {
                            message = "The Keychain didn't accept the key. Please try again."
                        }
                    }
                    .disabled(keyText.trimmingCharacters(in: .whitespaces).count < 10)
                }
                if let message { Text(message).font(.caption).foregroundStyle(Theme.textSecondary) }
                Link("Get a free USDA key (takes a minute)", destination: URL(string: "https://fdc.nal.usda.gov/api-key-signup")!)
            } header: {
                Text("USDA FoodData Central API (online brand-name foods)")
            } footer: {
                Text("Without a key, LeanTrack uses USDA's shared DEMO_KEY, which allows about 30 searches an hour. A free key allows 1,000 an hour. Type it here yourself; it's stored only in this iPhone's Keychain, never in backups or anywhere else.")
            }

            Section {
                Toggle("Search Open Food Facts too", isOn: $openFoodFactsEnabled)
            } footer: {
                Text("Open Food Facts is a free, crowd-sourced database of packaged foods from around the world (ODbL license). It's searched first for barcodes. Searches send only the words or barcode you look up.")
            }
        }
        .navigationTitle("Food Database")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - AI photo estimates

struct AIPhotoSettingsView: View {
    @State private var keyText = ""
    @State private var hasKey = KeychainStore.has(.anthropicAPIKey)
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                Text("Take a photo of your meal and Claude (Anthropic's AI) splits it into foods and estimates how many grams of each are on the plate. LeanTrack then looks up each food in the USDA database for the calories and nutrients, and you can adjust anything before adding it.")
                    .font(.subheadline)
            }
            Section {
                if hasKey {
                    Label("AI Photo Estimates are on. Your key is in the iOS Keychain.", systemImage: "checkmark.seal.fill").foregroundStyle(Theme.positive)
                    Button("Remove Key", role: .destructive) {
                        KeychainStore.set(nil, for: .anthropicAPIKey)
                        hasKey = false
                        message = "Removed. Photos now use only the on-device check."
                    }
                } else {
                    SecureField("Paste your Anthropic API key", text: $keyText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("settings.anthropicKey")
                    Button("Save Key") {
                        if KeychainStore.set(keyText, for: .anthropicAPIKey) {
                            hasKey = KeychainStore.has(.anthropicAPIKey)
                            keyText = ""
                            message = "Saved. Take a food photo from Add Food → camera to try it."
                        } else {
                            message = "The Keychain didn't accept the key. Please try again."
                        }
                    }
                    .disabled(keyText.trimmingCharacters(in: .whitespaces).count < 20)
                }
                if let message { Text(message).font(.caption).foregroundStyle(Theme.textSecondary) }
                Link("Get an API key from Anthropic", destination: URL(string: "https://console.anthropic.com/settings/keys")!)
            } header: {
                Text("Anthropic API key")
            } footer: {
                Text("Type or paste the key here yourself; never share it in a chat or message. It's stored only in this iPhone's Keychain and is never included in backups.")
            }
            Section("Cost and privacy") {
                Text("Anthropic bills your account for each photo you analyze (usually a few cents per photo, using the \(ClaudeFoodEstimator.model) model). You can set a spending limit in your Anthropic account.")
                Text("A photo is sent to Anthropic only when you take or choose one in Add Food while AI is on. It's sent over an encrypted connection, resized to 1,024 pixels, with no other information about you.")
                Text("Without a key, LeanTrack still recognizes common foods on-device with Apple's Vision framework (nothing leaves your iPhone), but it can't estimate portion sizes.")
            }
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
        }
        .navigationTitle("AI Photo Estimates")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Backup & Restore

struct BackupView: View {
    @Environment(\.modelContext) private var context
    @State private var exportURL: URL?
    @State private var importing = false
    @State private var pending: BackupFile?
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                if let exportURL {
                    ShareLink(item: exportURL) { Label("Save or Share Backup File", systemImage: "square.and.arrow.up") }
                        .accessibilityIdentifier("backup.share")
                } else {
                    Button { makeExport() } label: { Label("Create Backup", systemImage: "doc.badge.plus") }
                        .accessibilityIdentifier("backup.create")
                }
            } header: { Text("Back up") } footer: {
                Text("Creates one JSON file with your profile, diary, weigh-ins, water, exercise, custom foods, meals, recipes and favorites. Save it to Files or iCloud Drive. API keys are never included. Because LeanTrack is sideloaded, back up before you reinstall.")
            }
            Section {
                Button { importing = true } label: { Label("Restore from Backup…", systemImage: "arrow.down.doc") }
            } header: { Text("Restore") } footer: {
                Text("Replaces everything in the app with the backup.")
            }
            if let message {
                Section { Text(message).font(.subheadline) }
            }
        }
        .navigationTitle("Backup & Restore")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                do {
                    pending = try BackupService.decode(Data(contentsOf: url))
                } catch {
                    message = error.localizedDescription
                }
            case .failure(let error):
                message = error.localizedDescription
            }
        }
        .alert("Replace all data?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            Button("Replace", role: .destructive) {
                if let file = pending {
                    do {
                        try BackupService.restore(file, into: context)
                        message = "Restored: \(file.summary)."
                    } catch {
                        message = "Restore failed: \(error.localizedDescription)"
                    }
                }
                pending = nil
            }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: {
            if let file = pending {
                Text("The backup from \(file.exportedAt.formatted(date: .abbreviated, time: .shortened)) has \(file.summary). Everything currently in LeanTrack will be replaced.")
            }
        }
    }

    private func makeExport() {
        do {
            exportURL = try BackupService.exportFile(from: context)
            message = nil
        } catch {
            message = "Couldn't create the backup: \(error.localizedDescription)"
        }
    }
}

// MARK: - Help

struct HelpView: View {
    private struct FAQ: Identifiable {
        let question: String
        let answer: String
        var id: String { question }
        init(_ question: String, _ answer: String) { self.question = question; self.answer = answer }
    }

    private let faqs: [FAQ] = [
        FAQ("How do I add food?", "Tap the blue + (or \"Add Food\" in a Diary meal). Search, pick from Recent, Favorites, Common, Recipes or My Foods, scan a barcode, or take a photo. Tap + on a row to add its usual amount, or tap the row to choose the amount."),
        FAQ("Why do some nutrients show \"—\"?", "LeanTrack only shows real values from its sources. If USDA or a package label doesn't list a nutrient, LeanTrack shows — instead of guessing."),
        FAQ("How is my calorie goal worked out?", "Mifflin-St Jeor resting burn × your activity level, minus (or plus) your weekly pace × 3,500 ÷ 7. It never suggests less than 1,200 (women) or 1,500 (men) calories, or losing more than 2 lb or 1% of your weight a week. See Goals → Calorie Goal for the math."),
        FAQ("The app stopped opening after a week.", "Apps sideloaded with a free Apple ID expire after 7 days. Re-sign it with Sideloadly (connect the iPhone and sideload the same IPA again); your data stays as long as you don't delete the app."),
        FAQ("How do I keep my data safe?", "Settings → Backup & Restore → Create Backup, then save the file to Files or iCloud Drive. Do this before reinstalling or switching phones."),
        FAQ("Why isn't a barcode found?", "Not every product is in Open Food Facts or USDA's branded database. Create a custom food from the label; LeanTrack remembers the barcode for next time."),
        FAQ("How accurate are photo estimates?", "The on-device check names common foods but can't measure portions. AI estimates (with your own Anthropic key) also guess the grams from the photo, which is helpful but approximate, especially for oils, sauces and food you can't see."),
    ]

    var body: some View {
        List {
            ForEach(faqs) { faq in
                DisclosureGroup {
                    Text(faq.answer).font(.subheadline).foregroundStyle(Theme.textSecondary)
                } label: {
                    Text(faq.question).foregroundStyle(Theme.textPrimary)
                }
            }
            .listRowBackground(Theme.card)
            Section {
                Link("Report a problem on GitHub", destination: URL(string: "https://github.com/ggg291302-star/LeanTrack/issues")!)
            }
            .listRowBackground(Theme.card)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - About

struct AboutView: View {
    private struct Source: Identifiable {
        let name: String, use: String, license: String, url: String
        var id: String { name }
    }

    private let sources: [Source] = [
        Source(name: "USDA FoodData Central", use: "Built-in foods (Foundation, SR Legacy, FNDDS), online brand-name foods and barcodes, recipe nutrition", license: "Public domain (CC0 1.0)", url: "https://fdc.nal.usda.gov/"),
        Source(name: "Open Food Facts", use: "Barcodes and brand-name foods (optional)", license: "Database: ODbL 1.0 · Images: CC BY-SA", url: "https://world.openfoodfacts.org/"),
        Source(name: "CDC growth charts (2000) and extended BMI-for-age (2022)", use: "BMI percentiles for ages 2–19", license: "Public domain (U.S. government)", url: "https://www.cdc.gov/growthcharts/extended-bmi-data-files.htm"),
        Source(name: "CDC adult BMI categories", use: "BMI categories for adults", license: "Public domain (U.S. government)", url: "https://www.cdc.gov/bmi/adult-calculator/bmi-categories.html"),
        Source(name: "NHLBI Healthy Eating Recipes (NIH)", use: "54 recipes", license: "Public domain (17 U.S.C. § 105)", url: "https://www.nhlbi.nih.gov/health/heart-healthy-living/healthy-foods/healthy-eating-recipes"),
        Source(name: "Wikibooks Cookbook", use: "71 recipes (adapted: USDA matching and nutrition)", license: "CC BY-SA 4.0", url: "https://en.wikibooks.org/wiki/Cookbook:Table_of_Contents"),
        Source(name: "Wikimedia Commons", use: "118 recipe photos (credited on each recipe)", license: "Public domain, CC0, CC BY, CC BY-SA", url: "https://commons.wikimedia.org/"),
        Source(name: "Mifflin-St Jeor equation", use: "Resting energy (BMR)", license: "Mifflin MD et al., Am J Clin Nutr 1990;51:241–7", url: "https://pubmed.ncbi.nlm.nih.gov/2305711/"),
        Source(name: "FDA Daily Values", use: "% Daily Value", license: "21 CFR 101.9 (public domain)", url: "https://www.fda.gov/food/nutrition-facts-label/daily-value-nutrition-and-supplement-facts-labels"),
        Source(name: "Dietary Guidelines for Americans 2020–2025", use: "Fiber goal (14 g per 1,000 calories)", license: "Public domain (U.S. government)", url: "https://www.dietaryguidelines.gov/"),
        Source(name: "National Academies DRIs", use: "Water goal, macro ranges (AMDR), protein RDA", license: "Cited reference values", url: "https://nap.nationalacademies.org/read/10925/chapter/1"),
        Source(name: "NICE guideline NG246", use: "Waist-to-height ratio bands", license: "Cited reference values", url: "https://www.nice.org.uk/guidance/ng246"),
        Source(name: "NIST Handbook 44", use: "Unit conversions", license: "Public domain (U.S. government)", url: "https://www.nist.gov/pml/owm/nist-handbook-44-current-edition"),
        Source(name: "Apple Vision", use: "On-device food recognition in photos", license: "Part of iOS", url: "https://developer.apple.com/documentation/vision"),
        Source(name: "Anthropic Claude API (optional)", use: "AI portion estimates from photos, with your own key", license: "Anthropic terms", url: "https://www.anthropic.com/legal"),
    ]

    var body: some View {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        List {
            Section {
                LabeledContent("Version", value: "\(version) (\(build))")
                Link("Source code on GitHub", destination: URL(string: "https://github.com/ggg291302-star/LeanTrack")!)
            }
            .listRowBackground(Theme.card)
            Section("Data Sources & Licenses") {
                ForEach(sources) { s in
                    VStack(alignment: .leading, spacing: 3) {
                        Link(s.name, destination: URL(string: s.url)!).font(.subheadline.weight(.semibold))
                        Text(s.use).font(.caption).foregroundStyle(Theme.textSecondary)
                        Text(s.license).font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            .listRowBackground(Theme.card)
            Section("Disclaimer") {
                Text("LeanTrack gives general nutrition information and estimates. It isn't medical advice and doesn't diagnose or treat any condition. Talk to a doctor or registered dietitian before big changes to your diet or weight, especially if you're pregnant, breastfeeding, under 18, or have a health condition.")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
            }
            .listRowBackground(Theme.card)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

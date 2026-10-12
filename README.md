# LeanTrack

A personal, offline-first iPhone app for tracking calories, food, macros, water, weight and BMI.
No accounts, no servers, no ads. All data stays on the phone.

**What it does:** food diary with 13,364 offline USDA foods, brand-name foods and barcodes (USDA + Open Food Facts),
food photos (on-device, plus an optional Claude estimate with your own key), 125 recipes with photos, macros and every
nutrient vs goals, water, exercise, weigh-ins with trend and goal date, BMI (adults and CDC percentiles for kids),
reminders, and backup/restore. Every number comes from a named source: see [DATA_SOURCES.md](DATA_SOURCES.md).

- Native Swift + SwiftUI, SwiftData, Swift Charts (iOS 17+)
- The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- Built, tested and packaged as an unsigned IPA by GitHub Actions (`.github/workflows/build.yml`)
- Installed with Sideloadly: see [SIDELOAD-GUIDE.md](SIDELOAD-GUIDE.md)

Progress: [PLAN.md](PLAN.md) · Changes: [CHANGELOG.md](CHANGELOG.md)

Not medical advice. Personal use only.

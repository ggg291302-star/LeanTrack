# LeanTrack — Plan

The full requirements live in `BUILD-PROMPT.md`, and the target look is in `design-reference.webp`.
This file is the working checklist. Tick items as they're done so a future session can pick up where we left off.

## Decisions (locked in; ask the owner before changing any of these)

| Topic | Decision | Why |
|---|---|---|
| Owner's phone | iPhone 15/16/17 family on **iOS 26.5** | From Stage 0 |
| Minimum iOS | **iOS 17.0** | SwiftData needs iOS 17. This is the default from the prompt. |
| Bundle ID | **`com.ggg291302.leantrack`**. **Never change it.** | If it changes, reinstalling wipes all data on the phone. |
| Language / UI | Swift + SwiftUI, SwiftData (storage), Swift Charts | No third-party UI libraries |
| Project file | XcodeGen `project.yml` (no hand-written `.pbxproj`) | Editable on Windows |
| GitHub repo | **Public**: `github.com/ggg291302-star/LeanTrack` | Standard macOS runners are free and unlimited for public repos. No secrets or personal data ever go in the repo. |
| CI runner | **`macos-26`** (standard, Apple Silicon) | Newest stable standard macOS image (checked 2026-10-11). `-large`/`-xlarge` are paid "larger" runners. The `xcode-27` image is still Preview, so it's not used. |
| Xcode | **Xcode 26.6** (the image's default) | Newest stable Xcode on `macos-26` (image 20260907) |
| Test simulator | iPhone 17 Pro, **iOS 26.5** runtime | Same iOS as the owner's phone |
| IPA | Unsigned (`CODE_SIGNING_ALLOWED=NO`), `Payload/LeanTrack.app` zipped into `LeanTrack.ipa` | Sideloadly signs it with the owner's free Apple ID |
| Releases | Each run uploads a workflow artifact. Tags `v*` also create a GitHub Release with the IPA attached. | |
| Look | Custom dark design that matches the reference, with a custom tab bar and a center "+" button | iOS 26 "Liquid Glass" changes system bars. To keep the reference look, consider setting `UIDesignRequiresCompatibility`; decide after the Stage 1 screenshots. |
| Food DB | Built by a Node script in `scripts/` from USDA FDC (Foundation + SR Legacy + FNDDS) into one bundled SQLite file, read with the system `SQLite3` (no dependency). Node 24's built-in `node:sqlite` writes it. | Offline, fast, and under about 15 MB |
| API key | USDA key is entered by the owner in the app (Settings → Food Database) and stored in the iOS Keychain. Falls back to `DEMO_KEY`. | Never in code or the repo |

## Environment (Stage 0 check, 2026-10-11)

- Windows 10 Pro, PowerShell (execution policy blocks `npm.ps1`, so use `npm.cmd` / `npx.cmd`)
- git 2.55.0 ✅, node 24.19.0 ✅, npm 11.17.0 ✅, gh 2.98.0 ✅ (saved login has expired; owner re-runs `gh auth login`)
- Sideloadly installed ✅ (`%LOCALAPPDATA%\Sideloadly`)
- iTunes is the **Microsoft Store** version. Sideloadly says it needs the **web** (Apple website) versions of iTunes and iCloud, so swap them: winget `Apple.iTunes` and `Apple.iCloud` (Legacy).

## Stages

### Stage 0: Check and plan ✅
- [x] Read `BUILD-PROMPT.md` and study `design-reference.webp`
- [x] Ask for iPhone model and iOS version, GitHub account, public or private repo
- [x] Check installed tools (git, node, gh, Sideloadly, iTunes/iCloud)
- [x] Check the current GitHub runner images and Actions billing, and Sideloadly requirements
- [x] Write `PLAN.md`
- [x] Owner re-logged in to GitHub. (The terminal login prompt failed on Enter; running `gh auth login --web` in the background and having the owner type the code at github.com/login/device worked.)
- [ ] Owner: swap iTunes/iCloud to the web versions if Sideloadly can't see the phone (see `SIDELOAD-GUIDE.md`)

### Stage 1: Build pipeline plus an empty app on the phone
- [x] `git init` inside `LeanTrack`, and verify `git rev-parse --show-toplevel` is `LeanTrack` (not `New folder (5)`)
- [x] `.gitignore` (raw USDA downloads, build output, `.DS_Store`, etc.). `design-reference.webp` stays local and isn't published.
- [x] XcodeGen `project.yml`: app target, unit-test target, UI-test target, iOS 17.0, bundle ID above
- [x] Minimal app: dark theme, 5-tab custom bar (Home, Diary, +, Progress, More) with empty screens
- [x] Original app icon (`scripts/make-app-icon.mjs`, no copied art)
- [x] Folder layout: `App/ Models/ Services/ Features/<Screen>/ DesignSystem/` (`Data/` arrives in Stage 2)
- [x] Demo-data launch argument (`-LTDemoData`, compiled into Debug builds only). The in-memory store gets wired up in Stage 3 with SwiftData.
- [x] GitHub Actions workflow: XcodeGen → unsigned IPA → unit + UI tests on the simulator → screenshots / IPA / logs artifacts → Release on `v*` tags
- [x] Create the public GitHub repo with `gh` and push. First build passed (6/6 tests).
- [x] Download screenshots with `gh run download` and compare them to the reference (Add Food is now full screen; the "+" was shrunk to match)
- [x] `SIDELOAD-GUIDE.md` (download the IPA, Sideloadly + web iTunes/iCloud, Trust, Developer Mode, VPN & Device Management, 7-day re-sign, 3-app limit)
- [x] `CHANGELOG.md`
- [x] Tag `v0.1`. Release built with 6/6 tests passing: https://github.com/ggg291302-star/LeanTrack/releases/tag/v0.1
- [x] **Success:** the owner opened the empty LeanTrack app on their iPhone (2026-10-11): "so far, so good"

**Owner feedback after v0.1 (2026-10-11):** wants barcode scanning, a working "Today ▾" picker, tappable BMI/Recipes/More rows, adding food in the Diary, and calorie/macro targets. All of these are already planned in Stages 3–4.
**New request:** photo of food → calories. Plan (Stage 3): on-device Apple Vision `VNClassifyImageRequest` identifies the food → suggests matching USDA foods → the owner confirms the food and amount → calories come from USDA data. Portion size can't be measured from a photo. An optional cloud-AI upgrade (owner's own paid key) would be decided in Stage 3.

### Stage 2: Real data
- [x] `scripts/build-food-db.mjs`: downloads USDA FDC Foundation (2026-04), SR Legacy (2018-04) and FNDDS 2021–23 (2024-10), all CC0. Writes `LeanTrack/Resources/Data/foods.sqlite`: 13,364 foods, 31,527 portions, 5.0 MB. Uses Node's built-in `node:sqlite` and an own zip reader (no npm packages).
- [x] Raw downloads are git-ignored (`scripts/.cache`). The scripts and their outputs are committed.
- [x] Short display names (`shortName()`), with the original USDA name and FDC ID kept for the detail screen
- [x] Forgiving search: `FoodSearchIndex.swift` (prefix + 1–2 typos + ranking). "chiken brest" → chicken breast.
- [x] Common list: 172 foods (`scripts/data/common-foods.json`) with USDA default portions
- [x] Recipes: 125 total = 54 NHLBI (NIH, public domain; MyPlate.gov was down on 2026-10-11) + 71 Wikibooks (CC BY-SA 4.0). Ingredients are matched to USDA foods by `scripts/recipes/build-recipes.mjs` (dictionary + hand fixes in `recipe-curation.mjs`), and nutrition per serving is calculated from USDA data. 9 Wikibooks picks were excluded because amounts weren't measurable.
- [x] Recipe photos from Wikimedia Commons (owner request), free licenses only, with credits (`fetch-photos.mjs`)
- [x] CDC BMI-for-age 2022 data file (L, M, S, sigma, P95) bundled and cited, with the loader `CDCGrowthData.swift`. The percentile math is Stage 4.
- [x] `DATA_SOURCES.md`
- [x] Data tests: 10 foods vs the USDA API fixture, every recipe has a source and license, no recipe missing nutrition, nutrition re-adds from ingredients, Common list resolves, search finds typos and is fast, CDC worked-example rows
- [x] Report to owner: counts, file sizes, 10 sample foods, 5 sample recipes with sources
- [x] 118/125 recipes have a reviewed Commons photo (7.6 MB). App data total ≈ 13 MB.

**How to rebuild the data** (on Windows, from the `LeanTrack` folder):
`node scripts/build-food-db.mjs` → `node scripts/verify-foods.mjs` → `node scripts/fetch-cdc-bmi.mjs` → `node scripts/recipes/fetch-nhlbi.mjs` → `node scripts/recipes/fetch-wikibooks.mjs` → `node scripts/recipes/build-recipes.mjs` → `node scripts/recipes/fetch-photos.mjs` → `node scripts/recipes/build-recipes.mjs` (again, to attach photo credits)

### Stage 3: Food logging
- [ ] First-launch setup (profile, goal, pace, units)
- [ ] Home (ring, macro cards, remaining, today's meals, water card)
- [ ] Diary (week strip, meal sections, edit, swipe-delete, long-press move/copy, copy from yesterday)
- [ ] Add Food (Recent, Favorites, Common, Recipes, Brands; search; barcode via VisionKit + AVFoundation fallback; Open Food Facts → USDA Branded → create custom)
- [ ] Photo food recognition (owner request): camera/photo → on-device Vision classification → matching USDA foods → confirm portion → log
- [ ] Food / Meal Detail (donut, ingredients, serving picker with real USDA portions, meal picker, Add to Diary, "…" menu)
- [ ] Recipes (search, filters, detail, scaler, log serving, favorite, open original, my own recipes, optional online section if the terms allow)
- [ ] Custom foods, saved meals, Favorites, Recent
- [ ] Screenshots match the reference
- [ ] Release `v0.3`

### Stage 4: Weight, goals, BMI, and charts
- [ ] Weigh-ins (date, time, note), 7-day trend, projected goal date
- [ ] Progress (Weight/Calories/Macros, 1W–1Y, goal line, trend line, Average/Change)
- [ ] Nutrition (Calories/Nutrients/Macros, week chart with goal line, full nutrient details vs daily values)
- [ ] Goals (calories, macros in g and % kept in sync and summing to 100, fiber, water, + Add Goal)
- [ ] BMI Calculator (adult categories + gauge, healthy range, CDC percentiles 2–19, under-2 message, BMR, TDEE, waist-to-height, history chart, About BMI with CDC/WHO/NIH links)
- [ ] Goal math (TDEE ± pace × 3,500 / 7), macro presets, protein suggestion, offer to update after weight changes
- [ ] Safety guardrails (1,200/1,500 floors, ≤2 lb or 1% per week, low goal BMI warning, under 18 / pregnant / breastfeeding, disclaimer)
- [ ] Unit tests for all math, checked against official worked examples
- [ ] Release `v0.4`

### Stage 5: Settings, polish, and the final IPA
- [ ] Settings (Profile, Nutrition Goals, Notifications, Units, Appearance, Food Database key, Backup & Restore, Help, About)
- [ ] Local notifications (meal, weigh-in, water), all off by default
- [ ] Backup & Restore (JSON export/import via Share sheet / Files)
- [ ] Erase All Data (double confirm)
- [ ] About: version, Data Sources & Licenses, disclaimer
- [ ] Water tracker, exercise entries (add-back setting off by default), streak
- [ ] Accessibility pass (Dynamic Type, VoiceOver, contrast), empty states, offline messages, speed check
- [ ] Full code review and all tests green
- [ ] Tag `v1.0`, update `SIDELOAD-GUIDE.md`, final on-phone checklist

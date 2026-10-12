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

### Stage 0: Check and plan ✅ (waiting for owner OK)
- [x] Read `BUILD-PROMPT.md` and study `design-reference.webp`
- [x] Ask for iPhone model and iOS version, GitHub account, public or private repo
- [x] Check installed tools (git, node, gh, Sideloadly, iTunes/iCloud)
- [x] Check the current GitHub runner images and Actions billing, and Sideloadly requirements
- [x] Write `PLAN.md`
- [ ] Owner: re-login to GitHub (`gh auth login`), swap iTunes/iCloud to the web versions

### Stage 1: Build pipeline plus an empty app on the phone
- [ ] `git init` inside `LeanTrack`, and verify `git rev-parse --show-toplevel` is `LeanTrack` (not `New folder (5)`)
- [ ] `.gitignore` (raw USDA downloads, build output, `.DS_Store`, etc.)
- [ ] XcodeGen `project.yml`: app target, unit-test target, UI-test target, iOS 17.0, bundle ID above
- [ ] Minimal app: dark theme, 5-tab custom bar (Home, Diary, +, Progress, More) with empty screens
- [ ] Original app icon (generated, no copied art)
- [ ] Folder layout: `App/ Models/ Data/ Services/ Features/<Screen>/ DesignSystem/`
- [ ] Demo-data launch argument (`-LTDemoData`) using an in-memory store, never the real store
- [ ] GitHub Actions workflow: XcodeGen → unit + UI tests on the simulator → screenshots artifact → unsigned IPA artifact → Release on `v*` tags
- [ ] Create the public GitHub repo with `gh` and push. The build must pass.
- [ ] Download screenshots with `gh run download` and compare them to the reference
- [ ] `SIDELOAD-GUIDE.md` (download the IPA, Sideloadly + web iTunes/iCloud, Trust, Developer Mode, VPN & Device Management, 7-day re-sign, 3-app limit)
- [ ] `CHANGELOG.md`
- [ ] Tag `v0.1`
- [ ] **Success:** the owner opens the empty LeanTrack app on their iPhone

### Stage 2: Real data
- [ ] `scripts/build-food-db`: download USDA FDC Foundation, SR Legacy and FNDDS (CC0), keep only the needed fields and portions, and write `LeanTrack/Resources/foods.sqlite` (report its size)
- [ ] Raw downloads are git-ignored. The script and its output are committed.
- [ ] Short display names, with the original USDA name and FDC ID kept for the detail screen
- [ ] Forgiving search index (typos like "chiken brest")
- [ ] Common list: about 150 everyday foods with sensible default portions
- [ ] Recipes: at least 100 from public-domain (USDA/federal MyPlate Kitchen, checked per recipe) and CC BY-SA (Wikibooks Cookbook) sources, with ingredients mapped to USDA foods and nutrition per serving calculated by us
- [ ] CDC BMI-for-age LMS data (2–19 years), bundled and cited, plus the CDC extended BMI method for very high values
- [ ] `DATA_SOURCES.md` (URL, license, download date, use)
- [ ] Data tests: 10 foods spot-checked against USDA, every recipe has a source and license, no recipe missing nutrition
- [ ] Report: counts, file sizes, 10 sample foods, 5 sample recipes with sources

### Stage 3: Food logging
- [ ] First-launch setup (profile, goal, pace, units)
- [ ] Home (ring, macro cards, remaining, today's meals, water card)
- [ ] Diary (week strip, meal sections, edit, swipe-delete, long-press move/copy, copy from yesterday)
- [ ] Add Food (Recent, Favorites, Common, Recipes, Brands; search; barcode via VisionKit + AVFoundation fallback; Open Food Facts → USDA Branded → create custom)
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

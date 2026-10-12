# LeanTrack — build prompt

You are building an iPhone app for me from start to finish. Read this whole file first, then open and study `design-reference.webp` (in this same `LeanTrack` folder). It shows the 8 screens I want the app to look like.

---

## 1. Who I am and how to work with me

- I'm a beginner and not technical. I use a **Windows 10 PC** with PowerShell. Node and Git are installed. **I don't have a Mac.** I have an iPhone.
- Explain things in plain English and define any jargon the first time you use it.
- Give me exact PowerShell commands, one command per code block. My PowerShell blocks `npm.ps1`, so use `npm.cmd` / `npx.cmd`.
- Work in **stages** (section 9). After each stage, **stop**, show me a short success checklist (what I should see or tap), and wait for my "OK" before you continue. During long work, give me short progress updates.
- **Never ask me to paste passwords, API keys, my Apple ID, or tokens into the chat.** Tell me which screen or file to type them into myself.
- Ask me only about things you really need from me. Decide the rest yourself and tell me what you chose.
- If something in this prompt isn't possible (Apple limitation, license problem, an API changed), tell me plainly and suggest the closest alternative. Don't silently skip it.

## 2. The goal

Build a native iPhone app called **LeanTrack** (I may rename it later). It tracks calories, food, macros, water, weight loss or gain, and BMI.

Deliver it as an **.ipa file** that I can sideload onto my iPhone from Windows using **Sideloadly** and my free Apple ID.

- Personal use only. No App Store, no accounts, no servers, no ads, no premium, no paywall.
- All my data stays on my phone.

## 3. Where things go (important)

- Put everything in `New folder (5)\LeanTrack\`. This folder already holds this prompt and `design-reference.webp`.
- `New folder (5)` is a **separate, unrelated git repo** (a Minecraft mod). It also holds other projects (flipscout, ShieldScan, and more). **Never change, commit, move, or clean up anything outside `LeanTrack`.**
- Make `LeanTrack` its **own** git repo. Run `git init` inside `LeanTrack` first. Before your first commit, check that `git rev-parse --show-toplevel` prints the `LeanTrack` folder and not `New folder (5)`.

## 4. How to build an iPhone app without a Mac (already decided; ask me before changing it)

- **Native Swift + SwiftUI.** Use SwiftData for storage and Swift Charts for charts. Don't use third-party UI libraries. Add a dependency only if it really helps, and then only through Swift Package Manager.
- Define the Xcode project with **XcodeGen** (`project.yml`, a text file I can keep on Windows). Don't hand-write `.pbxproj` files.
- **GitHub Actions** builds the app on a GitHub-hosted macOS runner.
  - Use the newest stable *standard* (not "larger") macOS runner and the newest stable Xcode that GitHub currently offers. Check GitHub's runner-images list; don't guess.
  - Build an **unsigned** IPA (`CODE_SIGNING_ALLOWED=NO`), then zip `Payload/LeanTrack.app` into `LeanTrack.ipa`. Sideloadly signs it with my Apple ID when it installs.
  - Upload the IPA as a workflow artifact. On version tags (`v0.1`, `v1.0`, …), also attach it to a **GitHub Release** so I can download it easily.
- The same workflow runs the **unit tests and UI tests on an iPhone simulator** and saves a **screenshot of every main screen** as an artifact.
  - For screenshots, start the app with a test launch argument that loads a demo profile using **real foods from the bundled database**. That demo data must never show up in my real app.
  - You (Claude) download the screenshots with `gh run download` and **look at them** to compare against `design-reference.webp`. This is how you check the design, since there's no Mac here. Fix anything that doesn't match before you tell me a stage is done.
- Use the **`gh` CLI** to create the repo, push, watch runs, and read failure logs (`gh run view --log-failed`). I'll log in to GitHub myself with `gh auth login` in my browser; walk me through it.
- **Public vs private repo:** a public repo keeps the macOS builds free. A private repo only gets limited free macOS minutes. Check GitHub's current numbers, explain the tradeoff in one or two sentences, and let me choose. Never commit any secret either way.
- **Minimum iOS version:** in Stage 0, ask for my iPhone model and iOS version (Settings → General → About). Default to iOS 17 if my phone supports it, because SwiftData needs iOS 17.
- Choose a bundle ID like `com.<something>.leantrack` and **never change it**. If it changes, reinstalling would wipe my data.

## 5. Look and feel: match the picture

Study `design-reference.webp` closely and match its layout, spacing, colors, and style:

- Pure black background, dark-gray rounded cards (corner radius about 16), white main text, gray secondary text.
- iOS blue accent (about `#0A84FF`) for links, buttons, the selected tab, and the "+" button. Green for the calorie ring.
- Macro colors, used the same way everywhere (dots, rings, bars, legends): **Protein = green, Carbs = blue, Fat = orange.**
- System (SF) font with big bold numbers.
- Dark mode is the main look. The Appearance setting can also offer System and Light.
- Bottom tab bar: **Home, Diary, a big round blue "+" in the center, Progress, More.** The "+" opens Add Food for the meal that fits the time of day.
- **The numbers in the picture are fake samples, and some of them don't add up.** For example, 80 g of fat on a 2,400-calorie goal is 30% (not 23%), and the Home macro cards show two different percentages. Never copy numbers from the picture. Calculate everything from real data.
- Remove the crown icon (there's no premium). You can put a streak flame there instead, or leave it empty.
- The food photos in the picture are placeholders. Don't use copied images (see 6.1).

### Screens (left to right, top row then bottom row)

1. **Home**
   - "Today ▾" at the top opens a date picker.
   - A big calorie ring showing eaten vs goal ("1,245 of 2,400 Calories").
   - Three macro cards (Protein, Carbs, Fat). Each shows grams eaten, the share of the day's calories, and progress toward that macro's goal. Label each number so it's clear what it means.
   - A "Remaining" row: goal − food (+ exercise, if that setting is on).
   - "Today's Meals" list (icon, name, calories, P/C/F) with a "View all" link to Diary.
   - A small water card with quick add buttons.
2. **Food Diary**
   - Week strip (Sun–Sat) with the selected day highlighted, plus the day's total calories and a P/C/F summary.
   - Sections for Breakfast, Lunch, Dinner, and Snacks, each with its total. Each item shows an icon, name and amount, "cal • P • C • F", and a chevron. Each section has "+ Add Food".
   - Tap an item to edit its amount. Swipe to delete. Long-press to move or copy it to another meal or day. Add a quick "Copy from yesterday" for a meal.
3. **Add Food**
   - Top bar: Cancel, the title, and a barcode button. Below it, a search field.
   - Tabs: **Recent, Favorites, Common, Recipes, Brands.**
   - Each row: icon, name, "165 cal • 31g P • 0g C • 3.6g F" for the serving shown, and a "+" quick-add button.
4. **Food / Meal Detail**
   - Image or icon, name, calories, a macro donut with legend, and an ingredients list (for recipes and saved meals).
   - **Serving size picker:** an amount plus a unit (g, oz, cup, tbsp, piece, serving, …) using the food's *real* USDA portion data.
   - A meal picker and a big blue "Add to Diary" button.
   - "…" menu: Favorite, Edit, Delete (custom foods only).
5. **Nutrition**
   - Segmented control: Calories / Nutrients / Macros. Day arrows.
   - Week bar chart with a dashed goal line and today highlighted, plus totals.
   - "View Nutrition Details" opens the full nutrient list (fiber, sugar, sodium, saturated fat, cholesterol, potassium, and vitamins/minerals where the data exists) compared to daily values.
6. **Progress**
   - Segmented control: Weight / Calories / Macros. Range buttons: 1W 1M 3M 6M 1Y.
   - Weight line chart with a goal line and a 7-day trend line.
   - "Average" and "Change" boxes. The change is green when I'm moving *toward* my goal: weight going down if I'm losing, up if I'm gaining.
   - A "+ Log Weight" button.
7. **Goals**
   - Calorie Goal.
   - Macro Goals in grams and %. Keep grams and % in sync, and make the % always add up to 100.
   - Additional Goals: Fiber, Water, and "+ Add Goal" (for example sodium, sugar, or added sugar).
8. **Settings**
   - Profile (instead of "Account"), Nutrition Goals, Notifications, Units (lb or kg; ft/in or cm; oz or g; fl oz or ml), Appearance, Food Database (USDA key, see 6.1), Backup & Restore.
   - Help & Support (in-app help) and About (version, Data Sources & Licenses, disclaimer).
   - Replace "Log Out" (there are no accounts) with a red **"Erase All Data"** button that asks me to confirm twice.

**More tab:** a list in the same card style with **BMI Calculator** (required and new, see 6.3), Recipes, Nutrition, Goals, Weigh-ins, Water, Custom Foods & Meals, Backup & Restore, and Settings.

## 6. Real-world data rules (the most important part)

- **Real data only.** Every food, nutrient value, recipe nutrition number, and health formula must come from a real, named source. Never make up nutrition numbers. If a value is missing, show "—" instead of guessing.
- Create `DATA_SOURCES.md` listing every source with its URL, license, the date you downloaded it, and what the app uses it for. Show the same list in the app under Settings → About → Data Sources, with any required attribution (Open Food Facts requires ODbL attribution, for example).
- **Don't scrape websites.** Use official downloads, official APIs, and pages whose license allows reuse.

### 6.1 Foods

1. **Built-in offline food database** (works with no internet). Use the official **USDA FoodData Central** downloads: Foundation Foods, SR Legacy, and FNDDS ("survey" foods, which cover everyday foods and dishes like "pizza, cheese"). These are public domain (CC0).
   - Write a script in `scripts/` (Node is fine) that downloads the official files and keeps only what the app needs: name, category, calories, protein, carbs, fat, fiber, sugar, sodium, saturated fat, cholesterol, potassium, a sensible set of vitamins and minerals, and the **real portion sizes** ("1 cup", "1 large", "1 slice").
   - The script writes one compact bundled file (SQLite or JSON). Aim for under about 15 MB and tell me the real size.
   - Commit the script and its output, but not the huge raw downloads.
   - Search must be fast and forgiving. For example, "chiken brest" should find "Chicken, broilers or fryers, breast, meat only, cooked, roasted". Show short, readable names in lists, and the original USDA name and ID on the detail screen.
2. **Online search** (when there's internet): use the USDA FoodData Central API, which also includes branded and packaged foods.
   - Add a field under Settings → Food Database where *I* paste my own free key from api.data.gov. Walk me through getting the key.
   - Until I add a key, use `DEMO_KEY` and explain its low limits.
   - Store the key in the iOS **Keychain**. Never put it in the code or the repo.
3. **Barcode scanner:** scan with the camera (VisionKit DataScanner, with an AVFoundation fallback).
   - Look the barcode up in the **Open Food Facts** API (no key needed; send the User-Agent they ask for). If it's not there, try USDA Branded foods by UPC/GTIN.
   - If neither has it, offer "Create custom food" with the barcode already filled in.
4. **Common tab:** a hand-picked list of about 150 everyday foods from the USDA data (eggs, chicken breast, rice, oats, banana, apple, bread, milk, and so on), each with a sensible default portion.
5. **Brands tab:** packaged foods from USDA Branded and Open Food Facts (online). Slow the search down so we stay within their rate limits.
6. **Custom foods and saved meals:** I can enter my own foods and combine several foods into a saved meal like "Chicken, Rice & Broccoli".
7. **Pictures:** don't copy images from the web. Use SF Symbols, emoji, or simple original icons per food category. Open Food Facts product photos are OK for scanned products (CC BY-SA), with attribution.

### 6.2 Built-in recipes (real recipes collected online)

- Bundle **at least 100 recipes**: breakfast, lunch, dinner, snacks, high-protein, low-calorie, and vegetarian.
- Only use sources whose license allows reuse:
  - **U.S. government public-domain recipes**, for example **USDA MyPlate Kitchen** (myplate.gov/myplate-kitchen). **Check each recipe's credit line.** Only take recipes credited to USDA or another federal program. Skip recipes credited to outside companies, universities, or states unless their own license allows reuse.
  - **Openly licensed collections**, for example the Wikibooks Cookbook (CC BY-SA), with attribution.
- **Don't copy recipes from regular recipe websites or blogs** (AllRecipes, Food Network, and so on). They're copyrighted.
- Store each recipe with: title, source name, source URL, license, servings, prep and cook time, ingredients (amount, unit, and the matching USDA food), steps, and tags.
- **Calculate nutrition per serving yourself** from the ingredients using the USDA data, and show "Nutrition calculated from USDA data". If the source also prints nutrition, use it only to sanity-check your numbers.
- **Recipes screen:** search; filters (meal, tag, calories, protein); recipe detail with ingredients, steps, a servings scaler, and nutrition; "Log 1 serving" to Diary; Favorite; and "Open original" (a link to the source).
- **I can create my own recipes** from foods in the database, with nutrition calculated automatically.
- **Optional online extra:** if a free recipe API's terms allow this personal use (for example TheMealDB with its test key), add an "Online" section that shows results live with a link to the source. Don't bundle its content. Check its terms first and tell me what you found.

### 6.3 BMI Calculator and body math (More → BMI Calculator)

Use real published formulas and cutoffs, and show the sources in the app.

- **Inputs:** height (ft/in or cm), weight (lb or kg), age, and sex. Fill them in from my profile and latest weigh-in, and let me edit them.
  - "My BMI" mode saves my result. "Try other numbers" mode calculates without saving.
- **BMI** = kg ÷ m² (or 703 × lb ÷ in²), shown with 1 decimal.
- **Adults (20 and older), CDC/WHO categories:**
  - Underweight: below 18.5
  - Healthy weight: 18.5 to under 25
  - Overweight: 25 to under 30
  - Obesity class 1: 30 to under 35
  - Obesity class 2: 35 to under 40
  - Obesity class 3: 40 or higher

  Show a colored gauge bar with a marker for where I am.
- **Healthy weight range for my height:** convert BMI 18.5 to under 25 back into lb or kg, and show how far I am from that range.
- **Ages 2–19:** calculate BMI-for-age percentile with the official **CDC growth chart LMS data files**. Bundle the CDC files and cite them.
  - Categories: underweight below the 5th percentile, healthy 5th to under 85th, overweight 85th to under 95th, obesity 95th and above.
  - Use CDC's extended method for very high BMIs if you implement it.
  - **Under age 2:** say that BMI isn't used for this age.
- **Also show:**
  - BMR, using the **Mifflin-St Jeor** formula.
  - TDEE (daily calorie burn), using the standard activity multipliers: 1.2 sedentary, 1.375 light, 1.55 moderate, 1.725 very active, 1.9 extra active.
  - Waist-to-height ratio, if I enter my waist (guideline: under 0.5).
- **BMI history chart** built from my weigh-ins.
- **"About BMI" section:** what BMI does and doesn't tell you (muscle, age, ethnicity, pregnancy). Mention that some guidelines use lower cutoffs for Asian adults. Include links to CDC, WHO, and NIH.
- **Unit tests** that check BMI, the categories, the percentiles, BMR, and TDEE against worked examples from the official sources.

### 6.4 Goals: lose, maintain, or gain weight

- **First-launch setup:**
  - name (optional), sex, birthdate, height, current weight, goal weight, activity level, and units
  - goal: lose, maintain, or gain
  - pace: for example 0.5, 1, 1.5, or 2 lb per week to lose, or 0.25–0.5 lb per week to gain
- **Calorie goal** = TDEE minus (or plus) the amount the pace needs, using about 3,500 calories per lb. Say clearly that this is an estimate. Let me override the goal by hand.
- **Safety guardrails:**
  - Don't suggest fewer than 1,200 calories a day (women) or 1,500 (men).
  - Don't suggest losing faster than about 2 lb (or 1% of body weight) per week.
  - Show a gentle warning if I set goals like these by hand.
  - Warn me if my goal weight would give a BMI under 18.5.
  - If I'm under 18, or I say I'm pregnant or breastfeeding, don't make a weight-loss calorie plan. Suggest talking to a doctor instead.
  - Show a "not medical advice" disclaimer.
- **Macro presets:** Balanced, High Protein, Low Carb, and Custom, plus a protein suggestion based on body weight.
- When my weight changes by a few pounds, offer to update my calorie goal. Ask first; never change it silently.
- **Weigh-ins:** date, time, and an optional note. Show a 7-day trend line so daily water-weight swings don't confuse me, and a projected goal date based on my real trend.

## 7. Other features

- Water tracker.
- Manual exercise entries. A setting decides whether exercise calories are added back to my budget; it's **off** by default.
- A streak counter (days logged in a row).
- **Local notifications** (no server needed): meal, weigh-in, and water reminders. All of them are off by default, with times I can edit.
- **Backup & Restore:** export everything to a JSON file through the Share sheet or the Files app, and import it back. Explain to me why this matters: if the sideloaded app gets deleted, its data is gone.
- **Accessibility:** large text (Dynamic Type) works, VoiceOver labels are set, and contrast is good.
- **Works offline**, except online search and barcode lookups, which show a friendly message when there's no internet.
- **Fast:** searching the bundled database takes under a second.

## 8. Quality rules (every stage)

- After every push, wait for the GitHub build. If it fails, read the log and fix it yourself before you report back. **Never say something works unless the build passed, the tests passed, and you looked at the screenshots.**
- Write unit tests for all the math: calories, macros, BMI, BMR/TDEE, unit conversions, serving-size conversions, and recipe nutrition.
- Keep the code organized (for example App, Models, Data, Services, Features/<Screen>, DesignSystem). Add comments only where they help.
- Keep `PLAN.md` (a stage checklist) and a short `CHANGELOG.md` up to date so a future session can pick up where you left off.

## 9. Stages (stop after each one and wait for my OK)

### Stage 0: Check and plan (no app code yet)
- Ask me: my iPhone model and iOS version, whether I already have a GitHub account, and (after explaining the tradeoff) public or private repo.
- Check what's installed (git, node, gh). Tell me what to install and exactly how, for example with `winget` commands that I run myself.
- Write `PLAN.md` with these stages as a checklist.

### Stage 1: Build pipeline plus an empty app running on my phone
- Create the git repo, the XcodeGen project, and a minimal app with the dark theme, the 5-tab bar (empty screens for now), and a simple original app icon.
- Create the GitHub repo and the Actions workflow: unsigned IPA, tests, simulator screenshots, artifacts, and a Release on tags.
- Write `SIDELOAD-GUIDE.md` in plain English, covering:
  - how to download the IPA
  - installing Sideloadly, plus Apple's iTunes and iCloud **from Apple's website, not the Microsoft Store** (check the current requirements on sideloadly.io)
  - plugging in the iPhone and tapping "Trust"
  - signing in to Sideloadly (I type my Apple ID into Sideloadly only, never into the chat), then installing
  - turning on **Developer Mode** (Settings → Privacy & Security) and trusting the developer profile (Settings → General → VPN & Device Management)
  - **the 7-day rule:** free Apple ID apps must be re-signed every 7 days. Explain how to refresh or reinstall over the top **without losing data** (same bundle ID, never delete the app first).
  - the 3-app limit for free Apple IDs
- **Success = I open the empty LeanTrack app on my iPhone.** Don't start Stage 2 until this works. Help me fix any errors; I'll send screenshots.

### Stage 2: Real data
- The food database script and its bundled file, the Common list, and the recipe collection (sources, licenses, and calculated nutrition).
- The CDC BMI-for-age data and `DATA_SOURCES.md`.
- Tests on the data, for example:
  - spot-check 10 foods against USDA's website
  - every recipe has a source and a license
  - no recipe is missing nutrition
- Show me: the number of foods and recipes, the file sizes, 10 sample foods, and 5 sample recipes with their sources.

### Stage 3: Food logging
- First-launch setup, Home, Diary, Add Food (all tabs, search, and barcode), Food/Meal Detail, Recipes, custom foods, saved meals, Favorites, and Recent.
- Compare the screenshots to the design reference and fix any differences.
- Release a test IPA (`v0.3`) so I can try it on my phone.

### Stage 4: Weight, goals, BMI, and charts
- Weigh-ins, Progress, Nutrition, Goals, **BMI Calculator in More**, the calorie and macro goal math, and the safety guardrails.
- Tests for all the math. Release `v0.4`.

### Stage 5: Settings, polish, and the final IPA
- Settings, notifications, Backup & Restore, Erase All Data, units, About / Data Sources / disclaimer, and the Help screen.
- An accessibility pass, empty states, friendly error messages, and a speed check.
- Review all the code for bugs and run every test.
- Tag `v1.0`, attach the IPA to a GitHub Release, and update `SIDELOAD-GUIDE.md`.
- Give me a final on-phone test checklist: what to tap and what should happen.

---

Start with **Stage 0** now.

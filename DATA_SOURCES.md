# Data Sources & Licenses

Every food, nutrient value, recipe and health number in LeanTrack comes from a named source below.
Nothing is made up: when a source has no value, the app shows "—".
The app shows the same list under **Settings → About → Data Sources**.

| Source | What LeanTrack uses it for | License | Downloaded |
|---|---|---|---|
| USDA FoodData Central: Foundation Foods | Built-in food database | Public domain (CC0 1.0) | 2026-10-11 |
| USDA FoodData Central: SR Legacy | Built-in food database | Public domain (CC0 1.0) | 2026-10-11 |
| USDA FoodData Central: FNDDS 2021–2023 (Survey Foods) | Built-in food database (everyday foods and dishes) | Public domain (CC0 1.0) | 2026-10-11 |
| CDC 2022 Extended BMI-for-Age data file | BMI percentiles for ages 2–19 | Public domain (U.S. government work) | 2026-10-11 |
| NHLBI (NIH) Healthy Eating Recipes | 54 bundled recipes | Public domain (U.S. government work) | 2026-10-11 |
| Wikibooks Cookbook | 71 bundled recipes | CC BY-SA 4.0 | 2026-10-11 |
| Wikimedia Commons | 118 recipe photos | Per photo: public domain, CC0, CC BY or CC BY-SA | 2026-10-11 |
| NIST Handbook 44, Appendix C | Unit conversions (lb↔kg, oz↔g, in↔cm, fl oz↔ml) | Public domain (U.S. government work) | 2026-10-11 |
| USDA FoodData Central API (online) | Brand-name food search and barcode lookups | Public domain (CC0 1.0) | Live, when used |
| Open Food Facts (online, optional) | Barcode lookups and brand-name food search | Database: ODbL 1.0 · Contents: DbCL 1.0 · Images: CC BY-SA 3.0 | Live, when used |
| Published formulas and reference values | BMR, TDEE, BMI categories, % Daily Value, fiber, water, macro ranges, waist-to-height | Cited below | — |
| Apple Vision (on-device) | Naming foods in photos | Part of iOS | — |
| Anthropic Claude API (optional, owner's own key) | Splitting a food photo into foods and estimating grams | Anthropic's terms | Live, when used |


---

## USDA FoodData Central

- **Website:** https://fdc.nal.usda.gov/
- **Files** (from https://fdc.nal.usda.gov/download-datasets/):
  - Foundation Foods, April 2026: `FoodData_Central_foundation_food_json_2026-04-30.zip`
  - SR Legacy, April 2018: `FoodData_Central_sr_legacy_food_json_2018-04.zip`
  - FNDDS 2021–2023, October 2024: `FoodData_Central_survey_food_json_2024-10-31.zip`
- **License:** "USDA FoodData Central data are in the public domain and they are not copyrighted. They are published under CC0 1.0 Universal." (https://fdc.nal.usda.gov/api-guide/)
- **Citation (as USDA requests):** U.S. Department of Agriculture, Agricultural Research Service. FoodData Central, 2019. fdc.nal.usda.gov.
- **How LeanTrack uses it:**
  - `scripts/build-food-db.mjs` keeps each food's name, category, nutrients (calories, protein, carbs, fat, fiber, sugars, saturated/trans/mono/poly fat, cholesterol, sodium, potassium, calcium, iron, magnesium, phosphorus, zinc, vitamins A, C, D, E, K, B1, B2, B3, B6, B12, folate (DFE), caffeine, alcohol) and real USDA portion weights. It writes them to `LeanTrack/Resources/Data/foods.sqlite`.
  - When a newer Foundation food replaces the same food in SR Legacy (same NDB number), the Foundation values are used. Only nutrients Foundation hasn't measured are filled from the SR Legacy record, and the detail screen says so.
  - Foods without a calorie value are left out (34 foods).
  - Spot-checked against USDA's live API: `scripts/verify-foods.mjs` → `LeanTrackTests/Fixtures/usda-spot-check.json` (10 foods, all match).
  - The **Common** list (`scripts/data/common-foods.json`) is a hand-picked list of 172 foods, each with a default USDA portion.
  - Recipe nutrition is calculated from these foods (see Recipes below).

## CDC BMI-for-age (children and teens, 2–19 years)

- **File:** https://www.cdc.gov/growthcharts/data/extended-bmi/bmi-age-2022.csv, bundled unchanged as `LeanTrack/Resources/Data/cdc-bmi-for-age-2022.csv`
- **Page:** https://www.cdc.gov/growthcharts/extended-bmi-data-files.htm
- **License:** U.S. government work, public domain.
- **Contents:** L, M, S (2000 CDC growth charts) and sigma and P95 (2022 extended charts for BMIs above the 95th percentile), by sex and month of age.
- **Citations:**
  - Flegal KM, Cole TJ. Construction of LMS parameters for the Centers for Disease Control and Prevention 2000 growth chart. National Health Statistics Reports; no 63. Hyattsville, MD: National Center for Health Statistics. 2013.
  - Wei R, Ogden CL, Parsons VL, Freedman DS, Hales CM. A method for calculating BMI z-scores and percentiles above the 95th percentile of the CDC growth charts. Ann Hum Biol. 2020;47(6):514–521.

## Recipes

Every recipe stores its title, source, source URL, license, servings, times, ingredients (each matched to a USDA food and gram weight), steps and tags.
**Nutrition per serving is calculated by LeanTrack from the ingredients with USDA data** ("Nutrition calculated from USDA data"). Printed source nutrition, where it exists, was only used to sanity-check.
Ingredients without a measurable amount ("salt to taste", "optional", "a handful") are listed but not counted, and the app says so.

### NHLBI Healthy Eating Recipes (54 recipes)
- **Source:** National Heart, Lung, and Blood Institute, National Institutes of Health, https://www.nhlbi.nih.gov/health/heart-healthy-living/healthy-foods/healthy-eating-recipes
- **License:** Works of the U.S. federal government are not subject to copyright in the U.S. (17 U.S.C. § 105). Only recipes credited to NHLBI's own publications are included: *Deliciously Healthy Dinners*, *Deliciously Healthy Family Meals*, *Stay Young at Heart*, *Heart Healthy Home Cooking African American Style*, *Delicious Heart Healthy Latino Recipes*, *Honoring the Gift of Heart Health*, *Healthy Heart, Healthy Family*, *Your Health Is Golden!*
- **Fetched by:** `scripts/recipes/fetch-nhlbi.mjs` (one page per second, cached).

### Wikibooks Cookbook (71 recipes)
- **Source:** https://en.wikibooks.org/wiki/Cookbook:Table_of_Contents, read through the official MediaWiki API (`scripts/recipes/fetch-wikibooks.mjs`)
- **License:** Creative Commons Attribution-ShareAlike 4.0 (https://creativecommons.org/licenses/by-sa/4.0/). Each recipe credits "Wikibooks contributors" with a link to the page history and the revision used.
- **Changes made by LeanTrack:** ingredients matched to USDA foods, and nutrition calculated. Under ShareAlike, LeanTrack's version of these recipes is also CC BY-SA 4.0.
- Recipes were left out when an ingredient amount can't be measured honestly (for example "1 pack", "1 teacup", "1 bunch", or a recipe that counts 500 ml of frying oil).

### USDA MyPlate Kitchen
- Planned as a source, but on 2026-10-11 myplate.gov failed with a certificate/configuration error ("Azure Front Door configuration not found"), so nothing was taken from it.

## Recipe photos: Wikimedia Commons
- **Source:** https://commons.wikimedia.org/, read through the official API (`scripts/recipes/fetch-photos.mjs`)
- **Licenses:** only public domain, CC0, CC BY or CC BY-SA photos are used. The photographer and license of each photo are stored in `scripts/data/recipes/photos.json` and `recipes.json`, and shown under the photo in the app.
- 118 of 125 recipes have a photo. Every pick was reviewed by eye, and 7 recipes show a food icon because no fitting free photo was found.
- Licenses used: CC BY-SA 4.0 (36), CC BY 2.0 (34), CC BY-SA 2.0 (15), CC0 (11), CC BY-SA 3.0 (8), CC BY 4.0 (7), CC BY 3.0 (2), CC BY-SA 2.5 (2), public domain (2), CC BY-SA 1.0 (1).
- Photos are resized to 480 px wide (allowed by all of these licenses). Each photo shows the dish in general, not the exact recipe as made by the source.

## Unit conversions: NIST
- NIST Handbook 44, Appendix C (General Tables of Units of Measurement): 1 lb = 0.45359237 kg, 1 oz = 28.349523125 g, 1 in = 2.54 cm, 1 US fl oz = 29.5735295625 ml (exact definitions).
- https://www.nist.gov/pml/owm/nist-handbook-44-current-edition

## USDA FoodData Central API (online)
- **API:** https://fdc.nal.usda.gov/api-guide/ (`/fdc/v1/foods/search`, data type "Branded")
- **License:** public domain (CC0 1.0), same as the downloaded datasets.
- **Key:** the owner's free api.data.gov key is kept as a GitHub Actions secret (`USDA_API_KEY`) and added to the app only at build time (`scripts/ci/inject-secrets.py`); it's never in the code or the repo. Builds without the secret fall back to USDA's shared `DEMO_KEY` (about 30 requests an hour). Barcodes are looked up in USDA Branded first, because its label data comes from the manufacturers.
- **How LeanTrack uses it:** brand-name search (Add Food → search → "Brands (online)") and barcode lookups after Open Food Facts. Branded nutrient values are per 100 g (or 100 ml); vitamin D in IU is converted at 40 IU = 1 µg; vitamin A in IU is not converted (it can't be turned into RAE reliably), so it shows "—".

## Open Food Facts (online, optional)
- **Website / API:** https://world.openfoodfacts.org/ · https://openfoodfacts.github.io/openfoodfacts-server/api/
- **License:** database under the Open Database License (ODbL 1.0); individual contents under the Database Contents License (DbCL 1.0); product images under CC BY-SA 3.0. The app credits "Data © Open Food Facts contributors (ODbL)" on every Open Food Facts food and links to its product page.
- **How LeanTrack uses it:** first stop for barcode lookups (`/api/v2/product/<barcode>.json`) and part of brand-name search. Nutrients are read from `<nutrient>_100g` fields, which Open Food Facts stores in grams. Vitamin A and folate are not mapped, because labels don't say whether they're RAE/DFE; alcohol is not mapped because it's listed as % by volume. Data is crowd-sourced, so the app asks the owner to check it against the package.
- **Etiquette:** requests send a `User-Agent` naming the app and its GitHub page (no personal data), searches are debounced, and results are cached for the session. It can be turned off in **Settings → Food Database**.

## Formulas and reference values
| What | Value | Source |
|---|---|---|
| Resting energy (BMR) | Mifflin-St Jeor: 10 × kg + 6.25 × cm − 5 × age + 5 (men) or − 161 (women) | Mifflin MD, St Jeor ST, et al. Am J Clin Nutr. 1990;51(2):241–247. https://pubmed.ncbi.nlm.nih.gov/2305711/ |
| Total daily burn (TDEE) | BMR × 1.2 / 1.375 / 1.55 / 1.725 / 1.9 | Standard activity factors used with Mifflin-St Jeor |
| Weight change | About 3,500 kcal per pound (shown in the app as an estimate) | Long-used rule of thumb; the app tells the owner to watch the real trend |
| Safety guardrails | No suggested goal below 1,200 kcal (women) / 1,500 kcal (men); no loss faster than 2 lb or 1% of body weight a week; no loss plans under 18 or while pregnant/breastfeeding; warning when the goal BMI is under 18.5 | Common clinical guidance (e.g. NIH NHLBI); the app always recommends talking to a doctor |
| BMI | kg ÷ m²; adult categories under 18.5, 18.5–24.9, 25–29.9, 30–34.9, 35–39.9, 40+ | CDC: https://www.cdc.gov/bmi/adult-calculator/bmi-categories.html |
| BMI ages 2–19 | LMS percentiles (2000 CDC growth charts); above the 95th percentile: 90 + 10 × Φ((BMI − P95) ÷ sigma); categories at the 5th, 85th and 95th percentiles and 120% of the 95th | CDC: https://www.cdc.gov/bmi/child-teen-calculator/bmi-categories.html · https://www.cdc.gov/growthcharts/extended-bmi.htm |
| Under 2 years | BMI not used; WHO weight-for-length charts recommended | CDC |
| % Daily Value | FDA Daily Values for adults and children 4+ (e.g. sodium 2,300 mg, fiber 28 g, saturated fat 20 g, vitamin D 20 µg, potassium 4,700 mg) | 21 CFR 101.9; https://www.fda.gov/food/nutrition-facts-label/daily-value-nutrition-and-supplement-facts-labels |
| Fiber goal | 14 g per 1,000 kcal | Dietary Guidelines for Americans 2020–2025, https://www.dietaryguidelines.gov/ |
| Water goal | 2.2 L (women) / 3.0 L (men) of total beverages a day | National Academies, Dietary Reference Intakes for Water, Potassium, Sodium, Chloride, and Sulfate (2005), https://nap.nationalacademies.org/read/10925/chapter/1 |
| Macro ranges and protein | AMDR: protein 10–35%, carbs 45–65%, fat 20–35%; protein RDA 0.8 g/kg; 4/4/9 kcal per gram | National Academies, Dietary Reference Intakes for Energy and Macronutrients (2005) |
| Caffeine goal (optional) | 400 mg a day | FDA guidance for healthy adults |
| Waist-to-height ratio | 0.4–0.49 no increased risk, 0.5–0.59 increased, 0.6+ high | NICE guideline NG246, https://www.nice.org.uk/guidance/ng246 |

## Photos of food
- **On-device:** Apple's Vision framework (`VNClassifyImageRequest`) runs on the iPhone; no photo leaves the phone. It names what it sees, and the app searches the built-in USDA foods for matches. It can't measure portions.
- **AI estimate (switched off for now; the owner chose not to pay for an API key):** when enabled, only with the owner's own Anthropic API key into **Settings → AI Photo Estimates** (stored in the iOS Keychain). The photo, resized to at most 1,024 px, is sent to the Claude API (`claude-opus-5-5`, https://docs.anthropic.com/) with a request to name each food and estimate its edible weight in grams. **Claude does not supply calories:** each food is matched to the built-in USDA database and the calories and nutrients come from USDA. The owner can change the matched food and the grams before logging. Anthropic bills the owner's account for each photo.

## What the app shows from these sources
- **Recipes:** only healthy ones are shown: no desserts or sweet baked goods, and at most 700 calories, 10 g saturated fat (half the Daily Value) and 25 g sugar a serving (102 of 125). "High Protein" means 20 g+ protein a serving, or 15 g+ with at least 30% of calories from protein.
- **Protein goal:** set from body weight: 1.6 g per kg (Balanced, Low Carb; Morton RW et al., Br J Sports Med 2018;52:376-384) or 2.0 g per kg (High Protein; ISSN position stand, Jager R et al., J Int Soc Sports Nutr 2017;14:20), kept between 10% and 40% of calories. The RDA of 0.8 g/kg is shown as the minimum.
- **Open Food Facts entries** marked "per serving" are read from their per-serving values. If any online numbers are wrong, the owner can correct them from the package label; the corrected food is saved as a custom food with the same barcode and used for later scans.

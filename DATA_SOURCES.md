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

Planned in later stages (added here when they're built): the USDA FoodData Central API and Open Food Facts (online and barcode search, Stage 3), and the published formulas and cut-offs for BMI, BMR and TDEE (Stage 4).

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

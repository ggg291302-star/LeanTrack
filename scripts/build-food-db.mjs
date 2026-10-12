// Builds LeanTrack's offline food database from the official USDA FoodData Central
// downloads (public domain, CC0): Foundation Foods, SR Legacy and FNDDS (survey foods).
//
// Output: LeanTrack/Resources/Data/foods.sqlite
//   foods     one row per food, nutrients per 100 g (NULL = USDA has no value, shown as "—")
//   portions  real USDA household measures ("1 cup, chopped" = 160 g)
//   common    the hand-picked Common list (scripts/data/common-foods.json)
//   meta      source files and build date
//
// Usage:  node scripts/build-food-db.mjs
// Raw downloads are cached in scripts/.cache (git-ignored).
import { DatabaseSync } from "node:sqlite";
import { existsSync, mkdirSync, readFileSync, rmSync, statSync } from "node:fs";
import { join } from "node:path";
import { ROOT, cachedDownload, readZip } from "./lib/files.mjs";

const BASE = "https://fdc.nal.usda.gov/fdc-datasets/";
export const SOURCES = {
  F: { name: "USDA FoodData Central: Foundation Foods", file: "FoodData_Central_foundation_food_json_2026-04-30.zip", release: "2026-04-30" },
  S: { name: "USDA FoodData Central: SR Legacy", file: "FoodData_Central_sr_legacy_food_json_2018-04.zip", release: "2018-04" },
  N: { name: "USDA FoodData Central: FNDDS 2021-2023 (Survey Foods)", file: "FoodData_Central_survey_food_json_2024-10-31.zip", release: "2024-10-31" },
};
const OUT_DIR = join(ROOT, "LeanTrack", "Resources", "Data");
const OUT = join(OUT_DIR, "foods.sqlite");

// Column -> USDA nutrient IDs, in order of preference. Units are USDA's (per 100 g).
export const NUTRIENTS = [
  ["kcal", [1008, 2048, 2047]], // Energy (kcal); Foundation often only has Atwater specific/general
  ["protein", [1003]],
  ["carbs", [1005, 1050]], // by difference; Foundation sometimes only "by summation"
  ["fat", [1004]],
  ["fiber", [1079]],
  ["sugar", [2000, 1063]],
  ["sat_fat", [1258]],
  ["trans_fat", [1257]],
  ["mono_fat", [1292]],
  ["poly_fat", [1293]],
  ["cholesterol", [1253]], // mg
  ["sodium", [1093]], // mg
  ["potassium", [1092]], // mg
  ["calcium", [1087]], // mg
  ["iron", [1089]], // mg
  ["magnesium", [1090]], // mg
  ["phosphorus", [1091]], // mg
  ["zinc", [1095]], // mg
  ["vit_a", [1106]], // µg RAE
  ["vit_c", [1162]], // mg
  ["vit_d", [1114]], // µg
  ["vit_e", [1109]], // mg alpha-tocopherol
  ["vit_k", [1185]], // µg phylloquinone
  ["thiamin", [1165]], // mg
  ["riboflavin", [1166]], // mg
  ["niacin", [1167]], // mg
  ["vit_b6", [1175]], // mg
  ["folate", [1190]], // µg DFE
  ["vit_b12", [1178]], // µg
  ["caffeine", [1057]], // mg
  ["alcohol", [1018]], // g
];

function loadFoods(code) {
  const zip = join(ROOT, "scripts", ".cache", SOURCES[code].file);
  const [data] = readZip(zip).values();
  return Object.values(JSON.parse(data.toString("utf8")))[0].filter(Boolean);
}

function nutrientValues(food) {
  const byId = new Map();
  for (const n of food.foodNutrients ?? []) {
    if (n?.nutrient?.id != null && typeof n.amount === "number") byId.set(n.nutrient.id, n.amount);
  }
  const out = {};
  for (const [col, ids] of NUTRIENTS) {
    const id = ids.find((i) => byId.has(i));
    out[col] = id === undefined ? null : byId.get(id);
  }
  return out;
}

// ---------- Portions ----------
const FRACTION = /^(\d+(?:\.\d+)?)(?:\s+(\d+)\/(\d+))?\s+(.+)$|^(\d+)\/(\d+)\s+(.+)$/;

function parseQuantity(text) {
  const m = text.match(FRACTION);
  if (!m) return { amount: 1, unit: text };
  if (m[5]) return { amount: Number(m[5]) / Number(m[6]), unit: m[7] };
  const whole = Number(m[1]);
  const frac = m[2] ? Number(m[2]) / Number(m[3]) : 0;
  return { amount: whole + frac, unit: m[4] };
}

function portionsFor(food, code) {
  const out = [];
  for (const p of food.foodPortions ?? []) {
    const grams = p.gramWeight;
    if (!(grams > 0)) continue;
    let amount, unit;
    if (code === "N") {
      const d = (p.portionDescription ?? "").trim();
      if (!d || /^quantity not specified$/i.test(d)) continue;
      ({ amount, unit } = parseQuantity(d));
    } else {
      amount = p.amount ?? p.value ?? 1;
      const mu = p.measureUnit?.name;
      const mod = (p.modifier ?? "").trim();
      if (mu && mu !== "undetermined") {
        if (mu === "RACC") unit = "serving (FDA reference amount)";
        else if (mu === "milliliter") unit = "ml";
        else unit = mu.toLowerCase() + (mod ? `, ${mod}` : "");
      } else {
        unit = mod || "serving";
      }
    }
    unit = unit.replace(/\s+/g, " ").trim();
    if (!unit || !(amount > 0)) continue;
    out.push({ amount: round(amount, 4), unit, grams: round(grams, 2) });
  }
  // Remove duplicates (same unit and same grams per unit).
  const seen = new Set();
  return out.filter((p) => {
    const key = p.unit.toLowerCase() + "|" + round(p.grams / p.amount, 2);
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

// ---------- Readable names ----------
const NOISE = new Set([
  "broilers or fryers", "meat only", "nfs", "fluid", "regular", "enriched", "year round average",
  "all commercial varieties", "all varieties", "all grades", "commercial", "prepared",
  "with added vitamin a and vitamin d", "with added vitamin a", "with added vitamin d",
  "includes usda commodity", "ns as to form", "ready-to-eat", "fresh",
]);
const METHODS = /^(roasted|grilled|fried|pan-fried|braised|broiled|boiled|baked|stewed|steamed|microwaved|simmered|poached|scrambled|hard-boiled|smoked)\b/i;

export function shortName(description) {
  let parts = description
    .replace(/\s*\((?:includes foods for usda'?s food distribution program|includes usda commodity[^)]*)\)/gi, "")
    .split(/,\s*/)
    .map((s) => s.trim())
    .filter(Boolean);
  parts = parts.filter((p, i) => i === 0 || !(NOISE.has(p.toLowerCase()) || /^with added vitamins? [a-z]( and vitamin [a-z])?$/i.test(p)));
  // "cooked, roasted" -> "roasted"
  parts = parts.filter((p, i) => !(p.toLowerCase() === "cooked" && parts[i + 1] && METHODS.test(parts[i + 1])));
  let name = parts.join(", ");
  // Tidy SR Legacy's shouting brand names a little ("McDONALD'S" stays, "CAMPBELL'S" -> "Campbell's").
  name = name.replace(/\b([A-Z][A-Z'&.]{3,})\b/g, (w) => (/[a-z]/.test(w) ? w : w[0] + w.slice(1).toLowerCase()));
  return name.charAt(0).toUpperCase() + name.slice(1);
}

// ---------- Food groups (for icons) ----------
// Checked against the first part of the food's name before its category, so
// "Egg, whole" (category "Dairy and Egg Products") gets an egg icon and
// "Orange juice" (category "Fruits and Fruit Juices") gets a drink icon.
const NAME_FIRST_RULES = [
  ["egg", /^eggs?\b/],
  ["drink", /\bjuice\b|\bnectar\b|^beverages?\b|\bsmoothie\b/],
];
const GROUP_RULES = [
  ["baby", /baby/],
  ["fastfood", /fast food|restaurant|burger|pizza|sandwich|taco|burrito|hot dog/],
  ["sweets", /ice cream|frozen dairy|cake|cookie|brownie|\bpie|doughnut|pastr|candy|candies|chocolate|sweets|dessert/],
  ["drink", /beverage|coffee|\btea\b|soft drink|soda|water|drink|liquor|beer|wine|cocktail|smoothie|shake/],
  ["fruit", /fruit|apple|banana|berr|orange|grape|melon/],
  ["vegetable", /vegetable|potato|salad|lettuce|tomato|carrot|\bcorn\b|onion|string beans|spinach|broccoli|greens/],
  ["poultry", /poultry|chicken|turkey/],
  ["fish", /fish|seafood|shellfish/],
  ["meat", /beef|pork|lamb|veal|game|meat|sausage|luncheon|frankfurter|bacon|cured|deli/],
  ["egg", /^eggs and omelets|omelet/],
  ["grain", /grain|pasta|rice|noodle|macaroni/],
  ["dairy", /cheese|milk|dairy|yogurt|cream/],
  ["legume", /legume|beans?\b|\bpeas\b|lentil|\bsoy|tofu/],
  ["nuts", /\bnuts?\b|seed/],
  ["cereal", /breakfast cereal|cereal|oatmeal|grits/],
  ["bakery", /bread|baked|\brolls?\b|bagel|tortilla|cracker|pancake|waffle|biscuit|muffin|toast/],
  ["snack", /snack|chip|popcorn|pretzel/],
  ["fat", /fats|\boils?\b|dressing|butter|margarine/],
  ["soup", /soup|sauce|gravy|gravies|\bdips?\b/],
  ["meal", /mixed dish|meals|entree|side dish|stir-fry|casserole/],
  ["spice", /spice|herb|condiment|\bsalt\b/],
];

export function groupFor(category, description) {
  const c = (category ?? "").toLowerCase();
  const d = description.split(",")[0].toLowerCase();
  for (const [group, re] of NAME_FIRST_RULES) if (re.test(d)) return group;
  for (const [group, re] of GROUP_RULES) if (re.test(c)) return group;
  for (const [group, re] of GROUP_RULES) if (re.test(d)) return group;
  return "other";
}

const round = (x, places) => Math.round(x * 10 ** places) / 10 ** places;

// ---------- Build ----------
async function main() {
  for (const s of Object.values(SOURCES)) await cachedDownload(BASE + s.file);

  const foundation = loadFoods("F");
  const sr = loadFoods("S");
  const survey = loadFoods("N");
  const srByNdb = new Map(sr.map((f) => [String(f.ndbNumber), f]));
  const replacedSr = new Set();
  const rows = [];

  for (const f of foundation) {
    const values = nutrientValues(f);
    const twin = srByNdb.get(String(f.ndbNumber));
    let filledFrom = null;
    let portions = portionsFor(f, "F");
    if (twin) {
      // Same food (same NDB number) in SR Legacy: keep the newer Foundation values and
      // fill only nutrients Foundation hasn't measured. Add SR's household measures.
      replacedSr.add(twin.fdcId);
      const old = nutrientValues(twin);
      for (const [col] of NUTRIENTS) {
        if (values[col] == null && old[col] != null) {
          values[col] = old[col];
          filledFrom = twin.fdcId;
        }
      }
      const extra = portionsFor(twin, "S").filter((p) => !portions.some((q) => q.unit.toLowerCase() === p.unit.toLowerCase()));
      portions = [...portions.filter((p) => !p.unit.startsWith("serving (FDA")), ...extra, ...portions.filter((p) => p.unit.startsWith("serving (FDA"))];
    }
    rows.push({ food: f, code: "F", values, filledFrom, portions, category: f.foodCategory?.description });
  }
  for (const f of sr) {
    if (replacedSr.has(f.fdcId)) continue;
    rows.push({ food: f, code: "S", values: nutrientValues(f), filledFrom: null, portions: portionsFor(f, "S"), category: f.foodCategory?.description });
  }
  for (const f of survey) {
    rows.push({ food: f, code: "N", values: nutrientValues(f), filledFrom: null, portions: portionsFor(f, "N"), category: f.wweiaFoodCategory?.wweiaFoodCategoryDescription });
  }

  // A calorie tracker can't use a food with no calorie value.
  const skipped = rows.filter((r) => r.values.kcal == null);
  const kept = rows.filter((r) => r.values.kcal != null);

  mkdirSync(OUT_DIR, { recursive: true });
  if (existsSync(OUT)) rmSync(OUT);
  const db = new DatabaseSync(OUT);
  db.exec(`
    PRAGMA journal_mode = DELETE;
    CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
    CREATE TABLE foods (
      id INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      usda_name TEXT NOT NULL,
      source TEXT NOT NULL,
      category TEXT,
      grp TEXT NOT NULL,
      filled_from INTEGER,
      ${NUTRIENTS.map(([c]) => `${c} REAL`).join(",\n      ")}
    );
    CREATE TABLE portions (
      food_id INTEGER NOT NULL,
      seq INTEGER NOT NULL,
      amount REAL NOT NULL,
      unit TEXT NOT NULL,
      grams REAL NOT NULL,
      PRIMARY KEY (food_id, seq)
    ) WITHOUT ROWID;
    CREATE TABLE common (
      rank INTEGER PRIMARY KEY,
      food_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      portion_amount REAL NOT NULL,
      portion_unit TEXT NOT NULL,
      portion_grams REAL NOT NULL
    );
  `);

  const insertFood = db.prepare(
    `INSERT INTO foods (id, name, usda_name, source, category, grp, filled_from, ${NUTRIENTS.map(([c]) => c).join(", ")})
     VALUES (${Array(7 + NUTRIENTS.length).fill("?").join(", ")})`
  );
  const insertPortion = db.prepare("INSERT INTO portions VALUES (?, ?, ?, ?, ?)");
  db.exec("BEGIN");
  let portionCount = 0;
  for (const r of kept) {
    const d = r.food.description.trim();
    insertFood.run(r.food.fdcId, shortName(d), d, r.code, r.category ?? null, groupFor(r.category, d), r.filledFrom,
      ...NUTRIENTS.map(([c]) => r.values[c]));
    r.portions.forEach((p, i) => insertPortion.run(r.food.fdcId, i + 1, p.amount, p.unit, p.grams));
    portionCount += r.portions.length;
  }

  // Common foods: hand-picked list, each with a default portion that must exist in USDA data.
  const commonPath = join(ROOT, "scripts", "data", "common-foods.json");
  let commonCount = 0;
  if (existsSync(commonPath)) {
    const common = JSON.parse(readFileSync(commonPath, "utf8"));
    const insertCommon = db.prepare("INSERT INTO common VALUES (?, ?, ?, ?, ?, ?)");
    const findPortion = db.prepare("SELECT amount, unit, grams FROM portions WHERE food_id = ? AND unit = ? ORDER BY seq LIMIT 1");
    const exists = db.prepare("SELECT id FROM foods WHERE id = ?");
    for (const [i, c] of common.entries()) {
      if (!exists.get(c.fdcId)) throw new Error(`Common food "${c.name}": FDC ID ${c.fdcId} not in database`);
      let portion;
      if (c.unit === "g") portion = { amount: c.amount, unit: "g", grams: c.amount };
      else if (c.unit === "oz") portion = { amount: c.amount, unit: "oz", grams: round(c.amount * 28.349523125, 2) };
      else {
        const p = findPortion.get(c.fdcId, c.unit);
        if (!p) throw new Error(`Common food "${c.name}" (${c.fdcId}): no USDA portion "${c.unit}"`);
        portion = { amount: c.amount, unit: c.unit, grams: round((p.grams / p.amount) * c.amount, 2) };
      }
      insertCommon.run(i + 1, c.fdcId, c.name, portion.amount, portion.unit, portion.grams);
      commonCount++;
    }
  }

  const meta = db.prepare("INSERT INTO meta VALUES (?, ?)");
  meta.run("built", new Date().toISOString().slice(0, 10));
  for (const [code, s] of Object.entries(SOURCES)) meta.run(`source.${code}`, `${s.name} (${s.release}) ${BASE}${s.file}`);
  db.exec("COMMIT");
  db.exec("VACUUM");
  db.close();

  const counts = { F: 0, S: 0, N: 0 };
  for (const r of kept) counts[r.code]++;
  console.log(`Foods: ${kept.length} (Foundation ${counts.F}, SR Legacy ${counts.S}, FNDDS ${counts.N})`);
  console.log(`  SR Legacy entries merged into newer Foundation entries: ${replacedSr.size}`);
  console.log(`  Skipped (no calorie value): ${skipped.length}${skipped.length ? " e.g. " + skipped.slice(0, 4).map((r) => r.food.description).join("; ") : ""}`);
  console.log(`Portions: ${portionCount}`);
  console.log(`Common foods: ${commonCount}`);
  console.log(`Wrote ${OUT}: ${(statSync(OUT).size / 1e6).toFixed(2)} MB`);
}

if (import.meta.url === `file:///${process.argv[1].replace(/\\/g, "/")}` || process.argv[1]?.endsWith("build-food-db.mjs")) {
  await main();
}

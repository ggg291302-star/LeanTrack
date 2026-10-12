// Spot-checks foods in foods.sqlite against USDA's live FoodData Central API
// (the same data the fdc.nal.usda.gov website shows) and writes the API's values to
// LeanTrackTests/Fixtures/usda-spot-check.json, which the unit tests compare against.
//
// Usage:  node scripts/verify-foods.mjs            (uses DEMO_KEY, fine for one call)
//         USDA_API_KEY=yourkey node scripts/verify-foods.mjs
import { DatabaseSync } from "node:sqlite";
import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { ROOT, USER_AGENT } from "./lib/files.mjs";

// A mix of all three datasets, including a Foundation food merged with its SR twin (hummus).
const SAMPLE = [171477, 2707152, 746782, 168917, 2709224, 175168, 2708408, 321358, 172470, 2708616];
// USDA nutrient numbers -> our columns. Energy: 208 (kcal), or 958/957 (Atwater specific/general) for Foundation.
const CHECK = { protein: ["203"], fat: ["204"], carbs: ["205"], kcal: ["208", "958", "957"] };

const key = process.env.USDA_API_KEY || "DEMO_KEY";
const url = `https://api.nal.usda.gov/fdc/v1/foods?fdcIds=${SAMPLE.join(",")}&format=abridged&api_key=${key}`;
const res = await fetch(url, { headers: { "User-Agent": USER_AGENT } });
if (!res.ok) throw new Error(`USDA API ${res.status}: ${await res.text()}`);
const foods = await res.json();

const db = new DatabaseSync(join(ROOT, "LeanTrack/Resources/Data/foods.sqlite"), { readOnly: true });
const row = db.prepare("SELECT * FROM foods WHERE id = ?");
const fixture = [];
let failures = 0;
for (const f of foods) {
  const ours = row.get(f.fdcId);
  const byNumber = new Map(f.foodNutrients.map((n) => [n.number, n.amount]));
  const expected = {};
  for (const [col, numbers] of Object.entries(CHECK)) {
    const n = numbers.find((x) => byNumber.has(x));
    if (n) expected[col] = byNumber.get(n);
  }
  const diffs = Object.entries(expected).filter(([col, v]) => Math.abs((ours?.[col] ?? NaN) - v) > 0.011);
  failures += diffs.length;
  console.log(`${diffs.length ? "MISMATCH" : "ok      "} ${f.fdcId} ${f.description}`);
  console.log(`         USDA: ${JSON.stringify(expected)}  ours: ${JSON.stringify(Object.fromEntries(Object.keys(expected).map((c) => [c, ours?.[c]])))}`);
  fixture.push({ fdcId: f.fdcId, description: f.description, dataType: f.dataType, ...expected });
}
if (foods.length !== SAMPLE.length) { console.log(`Expected ${SAMPLE.length} foods from the API, got ${foods.length}`); failures++; }

const dir = join(ROOT, "LeanTrackTests", "Fixtures");
mkdirSync(dir, { recursive: true });
writeFileSync(join(dir, "usda-spot-check.json"), JSON.stringify({
  source: "USDA FoodData Central API v1 (https://api.nal.usda.gov/fdc/v1/foods), format=abridged",
  checked: new Date().toISOString().slice(0, 10),
  foods: fixture,
}, null, 1) + "\n");
console.log(failures ? `\n${failures} mismatches` : "\nAll values match USDA.");
process.exit(failures ? 1 : 0);

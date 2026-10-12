// Builds LeanTrack/Resources/Data/recipes.json from the downloaded recipe sources.
// For every ingredient line: parse the amount, match it to a USDA food, convert to grams with
// USDA's own portion weights, then add up nutrients and divide by servings.
// Nutrition is OUR calculation from USDA data; printed source nutrition is only used to sanity-check.
//
// Usage:  node scripts/recipes/build-recipes.mjs [--report]
import { DatabaseSync } from "node:sqlite";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { ROOT } from "../lib/files.mjs";
import { DICTIONARY } from "./ingredient-dictionary.mjs";
import { LINE_OVERRIDES, RECIPE_META, WIKIBOOKS_PICKS } from "./recipe-curation.mjs";
import { NUTRIENTS } from "../build-food-db.mjs";

const REPORT = process.argv.includes("--report");
const db = new DatabaseSync(join(ROOT, "LeanTrack/Resources/Data/foods.sqlite"), { readOnly: true });
const foodByName = db.prepare("SELECT * FROM foods WHERE usda_name = ? ORDER BY source = 'N' LIMIT 1");
const foodById = db.prepare("SELECT * FROM foods WHERE id = ?");
const portionsOf = db.prepare("SELECT amount, unit, grams FROM portions WHERE food_id = ? ORDER BY seq");
const COLS = NUTRIENTS.map(([c]) => c);

// ---------- Amount parsing ----------
const FRACTIONS = { "½": 0.5, "¼": 0.25, "¾": 0.75, "⅓": 1 / 3, "⅔": 2 / 3, "⅛": 0.125, "⅜": 0.375, "⅝": 0.625, "⅞": 0.875 };
const NUM = String.raw`(?:\d+(?:\.\d+)?\s*[½¼¾⅓⅔⅛⅜⅝⅞]|\d+\s+\d+\/\d+|\d+\/\d+|\d+(?:\.\d+)?|[½¼¾⅓⅔⅛⅜⅝⅞]|a|an|one|two|three|four|five|six|half)`;
const WORDS = { a: 1, an: 1, one: 1, two: 2, three: 3, four: 4, five: 5, six: 6, half: 0.5 };

function toNumber(s) {
  s = s.trim().toLowerCase();
  if (s in WORDS) return WORDS[s];
  let m;
  if ((m = s.match(/^(\d+(?:\.\d+)?)\s*([½¼¾⅓⅔⅛⅜⅝⅞])$/))) return Number(m[1]) + FRACTIONS[m[2]];
  if ((m = s.match(/^(\d+)\s+(\d+)\/(\d+)$/))) return Number(m[1]) + Number(m[2]) / Number(m[3]);
  if ((m = s.match(/^(\d+)\/(\d+)$/))) return Number(m[1]) / Number(m[2]);
  if (s in FRACTIONS) return FRACTIONS[s];
  return Number(s);
}

const UNIT_WORDS = [
  ["floz", /^(fl\.? ?oz|fluid ounces?)\b/i], ["cup", /^(c|cups?)\b\.?/i], ["tbsp", /^(tbsps?|Tbsps?|TBSPS?|tablespoons?|Tablespoons?|tbs|Tbs|T)\b\.?/],
  ["tsp", /^(tsps?|Tsps?|teaspoons?|Teaspoons?|t)\b\.?/], ["oz", /^(oz|ounces?)\b\.?/i], ["lb", /^(lbs?|pounds?)\b\.?/i],
  ["kg", /^(kg|kilograms?)\b/i], ["g", /^(g|grams?)\b\.?/i], ["ml", /^(ml|milliliters?|millilitres?)\b/i],
  ["l", /^(l|liters?|litres?)\b/i], ["quart", /^(qts?|quarts?)\b/i], ["pint", /^(pints?|pts?)\b/i],
  ["dl", /^(dl|deciliters?|decilitres?)\b/i],
];
// US customary measures (NIST). A Wikibooks "pint" in a British recipe is rare enough to fix by hand.
const VOLUME_CUPS = { cup: 1, tbsp: 1 / 16, tsp: 1 / 48, floz: 1 / 8, ml: 1 / 236.588, l: 1000 / 236.588, dl: 100 / 236.588, quart: 4, pint: 2 };
const WEIGHT_G = { g: 1, kg: 1000, oz: 28.349523125, lb: 453.59237 };
const CONTAINER = /^(cans?|tins?|bags?|cartons?|box(?:es)?|jars?|packages?|packs?|pkgs?|containers?|fillets?|bottles?|tubs?|blocks?|ea\.?)(?=[\s(])/i;

/** "1½ C celery, chopped" -> { qty: 1.5, unit: "cup", rest: "celery, chopped" } */
export function parseLine(raw) {
  let line = raw.replace(/^(for [^:]{1,30}:)\s*/i, "").replace(/\s+/g, " ").trim();
  const m = line.match(new RegExp(`^(${NUM})(?:\\s*(?:–|-|to)\\s*(${NUM}))?\\s*(.*)$`, "i"));
  if (!m || !m[1] || /^(a|an|one|half)$/i.test(m[1]) && !/^\s*\S/.test(m[3])) return { qty: null, unit: null, rest: line };
  let qty = toNumber(m[1]);
  if (m[2]) qty = (qty + toNumber(m[2])) / 2; // "2–3 cloves" -> 2.5
  let rest = m[3].trim().replace(/^of\s+/i, "");
  // "1 can (15½ oz) chickpeas" / "2 boxes (16 oz each) squash" / "1 fillet (14 oz) salmon"
  const c = rest.match(CONTAINER);
  if (c) {
    const inner = rest.slice(c[0].length).match(new RegExp(`^\\s*\\((${NUM})\\s*-?\\s*(oz|ounces?|lb|g|fl oz)\\b[^)]*\\)\\s*(.*)$`, "i"));
    if (inner) {
      const size = toNumber(inner[1]);
      const unit = /^fl/i.test(inner[2]) ? "floz" : /^lb/i.test(inner[2]) ? "lb" : /^g$/i.test(inner[2]) ? "g" : "oz";
      // "2 cans (12 oz each)" is per can; "2 ea. (2 lb / 900 g)" gives the total.
      const total = /^ea/i.test(c[1]) || (qty > 1 && !/each/i.test(inner[0])) ? size : qty * size;
      return { qty: total, unit, rest: inner[3].replace(/^of\s+/i, ""), container: c[1].toLowerCase() };
    }
  }
  // Weight given per item: "4 (6-ounce) salmon fillets", "5 ea. 3-ounce steaks",
  // "1 halibut fillet (approximately 1 pound / 450 g)".
  const each = rest.match(new RegExp(`(?:^|\\(|\\s)(?:approximately |about |approx\\.? )?(${NUM})[- ]?(ounces?|oz|pounds?|lbs?|grams?|g)\\b`, "i"));
  if (each && !UNIT_WORDS.some(([, re]) => re.test(rest)) && (/^\s*(ea\.?\s*)?\(?\s*\d/.test(rest) || /\([^)]*\d[^)]*\)/.test(rest))) {
    const u = each[2].toLowerCase();
    const unit = u.startsWith("g") ? "g" : /^(p|l)/.test(u) ? "lb" : "oz";
    return { qty: qty * toNumber(each[1]), unit, rest: rest.replace(/\([^)]*\)/g, "").replace(/^\s*ea\.?\s*/i, "").replace(new RegExp(`${NUM}[- ]?(ounces?|oz)\\b`, "i"), "").trim() };
  }
  // "1 (6½-inch) pita" -> drop the size note
  rest = rest.replace(/^\([^)]*\)\s*/, "");
  for (const [unit, re] of UNIT_WORDS) {
    const u = rest.match(re);
    if (!u) continue;
    let after = rest.slice(u[0].length).replace(/^[.\s]+/, "").replace(/^of\s+/i, "");
    // "½ C (2 oz) cheddar": the stated weight is more precise than the volume
    const w = after.match(new RegExp(`^\\((${NUM})\\s*(oz|ounces?|g|lb)\\)\\s*(.*)$`, "i"));
    if (w && VOLUME_CUPS[unit]) {
      const wu = /^g$/i.test(w[2]) ? "g" : /^lb/i.test(w[2]) ? "lb" : "oz";
      return { qty: toNumber(w[1]), unit: wu, rest: w[3] };
    }
    after = after.replace(/^\([^)]*\)\s*/, ""); // "8 C (2 quarts) water"
    return { qty, unit, rest: after };
  }
  return { qty, unit: null, rest };
}

// ---------- Matching & grams ----------
function matchFood(text) {
  const t = text.toLowerCase();
  for (const [re, name] of DICTIONARY) if (re.test(t)) return { food: foodByName.get(name), name };
  return null;
}

const PREP_WORDS = ["chopped", "diced", "sliced", "shredded", "grated", "mashed", "crushed", "minced", "packed", "cubed", "pieces", "whole", "halves", "florets", "julienned"];

function gramsPerCup(food, text) {
  const t = text.toLowerCase();
  let best = null;
  for (const p of portionsOf.all(food.id)) {
    const u = p.unit.toLowerCase();
    const m = u.match(/^(cups?|tbsps?|tablespoons?|tsps?|teaspoons?|fl oz|ml|quarts?)\b/);
    if (!m) continue;
    const kind = m[1].startsWith("cup") ? 1 : /^(tbsp|tablespoon)/.test(m[1]) ? 1 / 16 : /^(tsp|teaspoon)/.test(m[1]) ? 1 / 48
      : m[1] === "fl oz" ? 1 / 8 : m[1] === "ml" ? 1 / 236.588 : 4;
    const perCup = p.grams / p.amount / kind;
    let score = 0;
    for (const w of PREP_WORDS) if (u.includes(w)) score += t.includes(w) ? 3 : -1;
    if (kind === 1) score += 1; // cup measures are the most precise
    if (/whipped|melted|packed/.test(u) && !t.includes(u.match(/whipped|melted|packed/)[0])) score -= 4;
    if (!best || score > best.score) best = { perCup, score, from: `${p.amount} ${p.unit} = ${p.grams} g` };
  }
  return best;
}

// Words in a recipe line -> words USDA uses for that item in its portion names.
const COUNT_NOUNS = {
  clove: ["clove"], stalk: ["stalk"], slice: ["slice"], spear: ["spear"], fillet: ["fillet"], bun: ["roll", "bun"],
  roll: ["roll"], leaves: ["leaf"], leaf: ["leaf"], sprig: ["sprig"], head: ["head"], ear: ["ear"], breast: ["breast"],
  thigh: ["thigh"], drumstick: ["drumstick"], pita: ["pita"], tortilla: ["tortilla"], wedge: ["wedge"], grape: ["grape"],
  chil: ["pepper"], can: ["can"], wrapper: ["paper", "wrapper"], egg: ["egg", "large"], yolk: ["yolk", "large"], cube: ["cube"], piece: ["piece"],
};

function gramsPerItem(food, text) {
  const t = text.toLowerCase();
  const ps = portionsOf.all(food.id);
  const size = t.match(/\b(extra large|small|medium|large|jumbo)\b/)?.[1];
  const nounKey = Object.keys(COUNT_NOUNS).find((n) => new RegExp(`\\b${n}`).test(t));
  const nounWords = nounKey ? COUNT_NOUNS[nounKey] : [];
  const candidates = [];
  for (const p of ps) {
    const u = p.unit.toLowerCase();
    if (/^(cups?|tbsps?|tablespoons?|tsps?|teaspoons?|fl oz|oz|lb|ml|serving|nlea)/.test(u)) continue;
    let score = 0;
    if (size && new RegExp(`(^|[^a-z])${size}\\b`).test(u) && !(size === "large" && /extra large/.test(u))) score += 4;
    if (!size && /\b(medium|regular)\b/.test(u)) score += 2;
    if (!size && /\blarge\b/.test(u) && !/extra/.test(u)) score += 1;
    if (nounWords.some((w) => u.includes(w))) score += 3;
    if (/\b(each|whole|fruit|item|egg whole|pepper|potato|plantain|banana)\b/.test(u)) score += 1;
    if (size === "medium" && /\bregular\b/.test(u)) score += 3;
    // Words the line shares with USDA's portion name ("1 lemon yields", "leaf inner").
    for (const w of u.split(/[^a-z]+/).filter((x) => x.length >= 4)) if (new RegExp(`\\b${w}`).test(t)) score += 2;
    if (/yield from|with refuse|with bone/.test(u)) score -= 1;
    // "1 onion" means a whole onion, not "1 slice" or "1 ring" of one.
    for (const part of ["slice", "ring", "piece", "strip", "leaf", "cubic", "wedge", "sprig", "stalk", "floweret", "spear", "cube", "tbsp", "chopped"]) {
      if (u.includes(part) && !t.includes(part)) score -= 3;
    }
    candidates.push({ perItem: p.grams / p.amount, score, from: `${p.amount} ${p.unit} = ${p.grams} g` });
  }
  candidates.sort((a, b) => b.score - a.score);
  return candidates[0] && candidates[0].score > 0 ? candidates[0] : null;
}

function resolveGrams(food, parsed, text) {
  const { qty, unit } = parsed;
  if (qty == null) return { error: "no amount" };
  if (unit && WEIGHT_G[unit]) return { grams: qty * WEIGHT_G[unit], how: `${qty} ${unit}` };
  if (unit && VOLUME_CUPS[unit]) {
    const pc = gramsPerCup(food, text);
    if (!pc) return { error: `no USDA volume portion for "${food.usda_name}"` };
    return { grams: qty * VOLUME_CUPS[unit] * pc.perCup, how: `${qty} ${unit} via USDA "${pc.from}"` };
  }
  const item = gramsPerItem(food, text);
  if (!item) return { error: `no USDA item portion for "${food.usda_name}"` };
  return { grams: qty * item.perItem, how: `${qty} × USDA "${item.from}"` };
}

const SKIP = [
  [/cooking spray/i, "cooking spray (negligible)"],
  [/\bto taste\b/i, "to taste (not measured)"],
  [/\(optional\)|optional\)?$/i, "optional (not counted)"],
  [/garnish/i, "garnish (not counted)"],
  [/skewers?|glasses|toothpicks/i, "not food"],
  [/ice cubes?|crushed ice|^\S*\s*dash\b|\bpinch(es)?\b|\bdrops?\b|\bsprinkle\b|\bsprigs?\b|\bsplash\b/i, "a pinch, dash or sprig (negligible)"],
  [/^(salt|pepper|sea salt)\b.*(pepper|taste|$)/i, "salt and pepper to taste (not measured)"],
  [/\bbay lea(f|ves)\b/i, "bay leaf (removed before serving)"],
];
// Plain water (but not water chestnuts, watermelon, or "packed in water").
const isWater = (text) => /\bwater\b/i.test(text) && !/chestnut|melon|packed in water|canned in water|in water,|water.packed|watercress/i.test(text)
  && /^[\d½¼¾⅓⅔⅛\s./–-]*(c|cups?|quarts?|pints?|tbsp|tsp|ml|dl|l|liters?)?\.?\s*(\([^)]*\)\s*)?(ice |cold |warm |hot |boiling |lukewarm |tap )?water\b/i.test(text);

// ---------- Recipe assembly ----------
const minutes = (s) => {
  if (!s) return null;
  const h = Number(s.match(/(\d+)\s*h/i)?.[1] ?? 0);
  const m = Number(s.match(/(\d+)\s*m/i)?.[1] ?? 0);
  return h * 60 + m || null;
};

function buildRecipe(src, sourceInfo) {
  const meta = RECIPE_META[src.id] ?? {};
  const servings = meta.servings ?? src.servings ?? parseInt(src.yields ?? "", 10);
  if (!servings) throw new Error(`No servings for ${src.id}`);
  const totals = Object.fromEntries(COLS.map((c) => [c, 0]));
  const missing = new Set();
  const ingredients = [];
  const problems = [];
  src.ingredients.forEach((text, i) => {
    const ov = LINE_OVERRIDES[`${src.id}#${i}`] ?? LINE_OVERRIDES[text];
    const entry = { text };
    if (ov?.skip || (!ov && (isWater(text) || SKIP.find(([re]) => re.test(text))))) {
      entry.note = ov?.skip ?? (isWater(text) ? "water (no calories)" : SKIP.find(([re]) => re.test(text))[1]);
      ingredients.push(entry);
      return;
    }
    const parsed = parseLine(ov?.parse ?? (ov?.amount ? `${ov.amount} ${text}` : text));
    if (parsed.qty == null && ov?.grams == null) {
      entry.note = "amount not given in the source (not counted)";
      ingredients.push(entry);
      problems.push(`  ~ [${i}] "${text}" -> no amount, not counted`);
      return;
    }
    const match = ov?.food ? { food: typeof ov.food === "number" ? foodById.get(ov.food) : foodByName.get(ov.food) }
      : matchFood(ov?.parse ? parseLine(text).rest : (/^(cans?|tins?)$/.test(parsed.container ?? "") ? "canned " : "") + parsed.rest);
    if (ov?.food && !match.food) throw new Error(`Override food not in database: "${ov.food}" (line "${text}")`);
    if (!match?.food) { problems.push(`  ? [${i}] "${text}" -> no USDA match`); ingredients.push({ ...entry, note: "UNMATCHED" }); return; }
    const res = ov?.grams != null ? { grams: ov.grams, how: ov.how ?? "override" } : resolveGrams(match.food, parsed, ov?.parse ?? parsed.rest);
    if (res.error) { problems.push(`  ? [${i}] "${text}" -> ${match.food.usda_name}: ${res.error}`); ingredients.push({ ...entry, note: "UNRESOLVED" }); return; }
    const f = match.food;
    for (const c of COLS) {
      if (f[c] == null) missing.add(c);
      else totals[c] += (f[c] * res.grams) / 100;
    }
    entry.fdcId = f.id;
    entry.grams = Math.round(res.grams * 10) / 10;
    if (ov?.note) entry.note = ov.note;
    ingredients.push(entry);
    if (REPORT) problems.push(`    [${i}] ${text}\n         = ${entry.grams} g ${f.usda_name} (${f.id})  [${res.how}]`);
  });

  const perServing = {};
  for (const c of COLS) perServing[c] = missing.has(c) ? null : Math.round((totals[c] / servings) * 10) / 10;
  perServing.kcal = Math.round(totals.kcal / servings);

  const tags = new Set(meta.tags ?? []);
  const meatLike = ingredients.some((g) => g.fdcId && /chicken|turkey|beef|pork|lamb|ham\b|bacon|sausage|fish|salmon|tuna|cod|tilapia|haddock|shrimp|crustacean|anchov|gelatin/i
    .test(foodById.get(g.fdcId).usda_name));
  if (!meatLike) tags.add("vegetarian");
  if (perServing.protein >= 20 && (perServing.protein * 4) / perServing.kcal >= 0.25) tags.add("high-protein");
  if (perServing.kcal <= 300) tags.add("low-calorie");

  return {
    recipe: {
      id: src.id,
      title: meta.title ?? src.title,
      summary: src.intro || null,
      source: sourceInfo.name(src),
      sourceURL: src.url,
      license: sourceInfo.license,
      licenseURL: sourceInfo.licenseURL,
      attribution: sourceInfo.attribution(src),
      servings,
      servingSize: meta.servingSize ?? src.servingSize ?? null,
      prepMinutes: minutes(src.prepTime ?? meta.prep),
      cookMinutes: minutes(src.cookTime ?? meta.cook),
      totalMinutes: minutes(src.time) ?? null,
      meals: meta.meals ?? ["dinner"],
      tags: [...tags].sort(),
      ingredients,
      steps: src.steps,
      tips: src.tips?.length ? src.tips : undefined,
      nutritionPerServing: perServing,
      nutritionNote: "Nutrition calculated from USDA data",
      printedNutritionPerServing: src.printed && Object.keys(src.printed).length ? src.printed : undefined,
    },
    problems,
  };
}

const SOURCES = {
  nhlbi: {
    name: (r) => `NHLBI (NIH), ${r.credit}`,
    license: "Public domain (U.S. federal government work, 17 U.S.C. § 105)",
    licenseURL: "https://www.law.cornell.edu/uscode/text/17/105",
    attribution: (r) => `Recipe from "${r.credit}", National Heart, Lung, and Blood Institute, National Institutes of Health.`,
  },
  wikibooks: {
    name: () => "Wikibooks Cookbook",
    license: "CC BY-SA 4.0",
    licenseURL: "https://creativecommons.org/licenses/by-sa/4.0/",
    attribution: (r) => `"${r.title}" by Wikibooks contributors (${r.historyUrl}), revision ${r.revision}, CC BY-SA 4.0. Ingredient matching and nutrition added by LeanTrack.`,
  },
};

const nhlbi = JSON.parse(readFileSync(join(ROOT, "scripts/data/recipes/nhlbi-raw.json"), "utf8"));
const wikiPath = join(ROOT, "scripts/data/recipes/wikibooks-raw.json");
const wiki = existsSync(wikiPath) ? JSON.parse(readFileSync(wikiPath, "utf8")).filter((r) => r.title in WIKIBOOKS_PICKS) : [];
for (const r of wiki) RECIPE_META[r.id] = { meals: WIKIBOOKS_PICKS[r.title], ...RECIPE_META[r.id] };

const out = [];
let problemCount = 0;
for (const [list, src] of [[nhlbi, SOURCES.nhlbi], [wiki, SOURCES.wikibooks]]) {
  for (const r of list) {
    if (RECIPE_META[r.id]?.exclude) continue;
    const { recipe, problems } = buildRecipe(r, src);
    const p = recipe.printedNutritionPerServing;
    const diff = p?.kcal ? Math.round(((recipe.nutritionPerServing.kcal - p.kcal) / p.kcal) * 100) : null;
    const unresolved = problems.filter((x) => x.startsWith("  ?")).length;
    problemCount += unresolved;
    const flag = unresolved ? "FIX " : diff != null && Math.abs(diff) > 25 ? "CHECK" : "ok  ";
    if (REPORT || flag !== "ok  ") {
      console.log(`${flag} ${recipe.id}  ${recipe.title}: ${recipe.nutritionPerServing.kcal} kcal/serving` +
        (p?.kcal ? ` (printed ${p.kcal}, ${diff > 0 ? "+" : ""}${diff}%)` : "") +
        `  P${recipe.nutritionPerServing.protein} C${recipe.nutritionPerServing.carbs} F${recipe.nutritionPerServing.fat}  [${recipe.tags.join(", ")}]`);
      if (problems.length) console.log(problems.join("\n"));
    }
    out.push(recipe);
  }
}
out.sort((a, b) => a.title.localeCompare(b.title));
// Attach photo credits found by fetch-photos.mjs (run it after this script, then run this again).
const photosPath = join(ROOT, "scripts/data/recipes/photos.json");
if (existsSync(photosPath)) {
  const photos = JSON.parse(readFileSync(photosPath, "utf8"));
  for (const r of out) if (photos[r.id]) r.photo = photos[r.id];
}
writeFileSync(join(ROOT, "LeanTrack/Resources/Data/recipes.json"), JSON.stringify({
  generated: new Date().toISOString().slice(0, 10),
  nutritionSource: "USDA FoodData Central (Foundation, SR Legacy, FNDDS) via foods.sqlite",
  recipes: out,
}, null, 1) + "\n");
console.log(`\n${out.length} recipes written (${out.filter((r) => r.id.startsWith("nhlbi")).length} NHLBI, ${out.filter((r) => r.id.startsWith("wikibooks")).length} Wikibooks); ${problemCount} ingredient lines still need fixing`);

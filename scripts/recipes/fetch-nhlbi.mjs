// Downloads the NHLBI (National Heart, Lung, and Blood Institute, NIH) "Healthy Eating Recipes".
// These are U.S. federal government works (17 U.S.C. § 105: no copyright in the U.S.).
// Only recipes whose "Recipe Source" credit is an NHLBI publication are kept.
// Polite: one request per second, cached in scripts/.cache/nhlbi, User-Agent identifies us.
//
// Output: scripts/data/recipes/nhlbi-raw.json (title, URL, credit, ingredient lines, steps, times, printed nutrition)
// Usage:  node scripts/recipes/fetch-nhlbi.mjs
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { ROOT, USER_AGENT, sleep } from "../lib/files.mjs";

const BASE = "https://www.nhlbi.nih.gov";
const LIST = "/health/heart-healthy-living/healthy-foods/healthy-eating-recipes";
const CACHE = join(ROOT, "scripts", ".cache", "nhlbi");
const OUT = join(ROOT, "scripts", "data", "recipes", "nhlbi-raw.json");

// NHLBI's own recipe books. Anything credited elsewhere is skipped.
const NHLBI_PUBLICATIONS = [
  "Deliciously Healthy Dinners", "Deliciously Healthy Family Meals", "Keep the Beat",
  "Heart Healthy Home Cooking African American Style", "Delicious Heart Healthy Latino Recipes",
  "Healthy Eating Recipes", "Stay Young at Heart", "Mediterranean", "DASH", "We Can!",
  "Platillos Latinos", "NHLBI", "National Heart, Lung, and Blood Institute",
  // NHLBI community health worker manuals (federal publications):
  "Honoring the Gift of Heart Health", "Healthy Heart, Healthy Family", "Your Health Is Golden",
];

async function get(path, cacheName) {
  const file = join(CACHE, cacheName);
  if (existsSync(file)) return readFileSync(file, "utf8");
  await sleep(1000);
  const res = await fetch(BASE + path, { headers: { "User-Agent": USER_AGENT } });
  if (!res.ok) throw new Error(`${res.status} for ${path}`);
  const html = await res.text();
  writeFileSync(file, html);
  return html;
}

const decode = (s) => s
  .replace(/<[^>]+>/g, " ")
  .replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&#0?39;|&rsquo;|&lsquo;/g, "'")
  .replace(/&quot;|&ldquo;|&rdquo;/g, '"').replace(/&ndash;/g, "–").replace(/&mdash;/g, "—")
  .replace(/&frac12;/g, "½").replace(/&frac14;/g, "¼").replace(/&frac34;/g, "¾").replace(/&deg;/g, "°")
  .replace(/\s+/g, " ").trim();

function field(html, name) {
  const m = html.match(new RegExp(`field--name-field-${name}[^>]*>([\\s\\S]*?)</div>`));
  return m ? decode(m[1]) : null;
}

// All list items between a heading ("Ingredients") and the next heading.
// Some recipes split ingredients into groups ("For spread:"), so collect every <li>.
function section(body, heading) {
  const re = new RegExp(`<h[23][^>]*>\\s*${heading}\\s*</h[23]>([\\s\\S]*?)(?=<h[23][^>]*>|$)`, "i");
  const m = body.match(re);
  if (!m) return [];
  return [...m[1].matchAll(/<li>([\s\S]*?)<\/li>/g)].map((x) => decode(x[1])).filter(Boolean);
}

function parseRecipe(html, slug) {
  const article = html.slice(html.indexOf("<article"));
  const title = decode(article.match(/<h1>\s*<span>([\s\S]*?)<\/span>/)?.[1] ?? "");
  const body = article.match(/field--name-body[^>]*>([\s\S]*?)<\/div>\s*<\/div>/)?.[1] ?? "";
  const credit = decode(body.match(/Recipe Source:\s*([\s\S]*?)<\/p>/i)?.[1] ?? "");
  const intro = decode(body.match(/<p>([\s\S]*?)<\/p>/)?.[1] ?? "");
  const ingredients = section(body, "Ingredients");
  const steps = section(body, "Directions");
  const tips = [...body.matchAll(/<p>\s*<strong>Tip:?<\/strong>([\s\S]*?)<\/p>/gi)].map((m) => decode(m[1]));
  const printed = {};
  for (const [key, name] of [["kcal", "calories"], ["fat", "total-fat"], ["sat_fat", "saturated-fat"], ["cholesterol", "cholesterol"],
    ["sodium", "sodium"], ["fiber", "total-fiber"], ["protein", "protein"], ["carbs", "carbohydrates"], ["potassium", "potassium"]]) {
    const v = field(html, name);
    if (v != null) printed[key] = parseFloat(v.replace(/,/g, ""));
  }
  return {
    id: `nhlbi-${slug}`, title, url: BASE + LIST + "/" + slug, credit, intro,
    prepTime: field(html, "prep-time"), cookTime: field(html, "cook-time"),
    yields: field(html, "yields"), servingSize: field(html, "serving-size"),
    ingredients, steps, tips, printed,
  };
}

mkdirSync(CACHE, { recursive: true });
mkdirSync(join(ROOT, "scripts", "data", "recipes"), { recursive: true });

// 1. Collect recipe links from every listing page.
const slugs = new Set();
for (let page = 0; page < 20; page++) {
  const html = await get(`${LIST}?page=${page}`, `list-${page}.html`);
  const found = [...html.matchAll(new RegExp(`href="${LIST}/([a-z0-9-]+)"`, "g"))].map((m) => m[1]);
  const before = slugs.size;
  found.forEach((s) => slugs.add(s));
  if (slugs.size === before) break;
}
console.log(`Found ${slugs.size} recipe pages`);

// 2. Download and parse each recipe.
const recipes = [];
const skipped = [];
for (const slug of slugs) {
  const r = parseRecipe(await get(`${LIST}/${slug}`, `${slug}.html`), slug);
  const nhlbiCredit = NHLBI_PUBLICATIONS.some((p) => r.credit.toLowerCase().includes(p.toLowerCase()));
  if (!nhlbiCredit) { skipped.push(`${r.title} (credit: "${r.credit || "none"}")`); continue; }
  if (!r.ingredients.length || !r.steps.length) { skipped.push(`${r.title} (couldn't read ingredients/steps)`); continue; }
  recipes.push(r);
}
writeFileSync(OUT, JSON.stringify(recipes, null, 1) + "\n");
console.log(`Kept ${recipes.length} recipes -> ${OUT}`);
if (skipped.length) console.log(`Skipped ${skipped.length}:\n  ` + skipped.join("\n  "));

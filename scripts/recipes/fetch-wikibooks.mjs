// Downloads recipe candidates from the Wikibooks Cookbook through the official MediaWiki API.
// License: Creative Commons Attribution-ShareAlike (CC BY-SA 4.0); attribution = page URL +
// "Wikibooks contributors" + link to the page history. Polite: batched requests, 1.5 s apart, cached.
//
// Output: scripts/data/recipes/wikibooks-raw.json (only recipes with clear amounts, servings and steps)
// Usage:  node scripts/recipes/fetch-wikibooks.mjs
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { join } from "node:path";
import { ROOT, USER_AGENT, sleep } from "../lib/files.mjs";

const API = "https://en.wikibooks.org/w/api.php";
const CACHE = join(ROOT, "scripts", ".cache", "wikibooks");
const OUT = join(ROOT, "scripts", "data", "recipes", "wikibooks-raw.json");
const CATEGORIES = ["Breakfast recipes", "Vegetarian recipes", "Vegan recipes", "Soup recipes", "Snack recipes",
  "Recipes using chicken", "Recipes using egg", "Recipes using beef", "Recipes using fish", "Recipes using rice",
  "Recipes using pasta", "Recipes using lentil", "Recipes using oats", "Salad recipes", "Main course recipes"];

async function api(params) {
  const query = new URLSearchParams({ format: "json", formatversion: "2", ...params }).toString();
  const file = join(CACHE, createHash("sha1").update(query).digest("hex") + ".json");
  if (existsSync(file)) return JSON.parse(readFileSync(file, "utf8"));
  let last = "";
  for (let attempt = 0; attempt < 6; attempt++) {
    await sleep(3000 * 2 ** attempt); // 3 s, then back off: 6, 12, 24, 48, 96 s
    const res = await fetch(`${API}?${query}`, { headers: { "User-Agent": USER_AGENT } });
    const text = await res.text();
    if (res.ok && text.startsWith("{")) {
      writeFileSync(file, text);
      return JSON.parse(text);
    }
    last = `${res.status} ${text.slice(0, 120)}`;
  }
  throw new Error(`Wikibooks API kept refusing (${last}): ${query}`);
}

async function categoryMembers(cat) {
  const titles = [];
  let cont = {};
  do {
    const j = await api({ action: "query", list: "categorymembers", cmtitle: `Category:${cat}`, cmlimit: "500", cmnamespace: "102", ...cont });
    titles.push(...(j.query?.categorymembers ?? []).map((m) => m.title));
    cont = j.continue ? { cmcontinue: j.continue.cmcontinue } : null;
  } while (cont);
  return titles;
}

// ---------- Wikitext parsing ----------
const clean = (s) => s
  .replace(/\[\[(?:[^\]|]*\|)?([^\]]*)\]\]/g, "$1") // [[Cookbook:Onion|onions]] -> onions
  .replace(/\{\{[^}]*\}\}/g, "")
  .replace(/'''?/g, "")
  .replace(/<ref[\s\S]*?<\/ref>|<[^>]+>/g, "")
  .replace(/\s+/g, " ")
  .trim();

function sectionLines(text, headings, marker) {
  const re = new RegExp(`^==+\\s*(?:${headings})\\s*==+\\s*$([\\s\\S]*?)(?=^==[^=]|(?![\\s\\S]))`, "im");
  const m = text.match(re);
  if (!m) return [];
  return m[1].split("\n").filter((l) => marker.test(l)).map((l) => clean(l.replace(marker, ""))).filter(Boolean);
}

function summaryField(text, name) {
  const m = text.match(new RegExp(`\\|\\s*${name}\\s*=\\s*([^|\\n}]*)`, "i"));
  return m ? clean(m[1]) : null;
}

const QTY = /^(\d+([.,/]\d+)?|\d+\s+\d+\/\d+|[½¼¾⅓⅔⅛]|\d+[½¼¾⅓⅔⅛]|a |an |one |two |three |four |half )/i;

function parse(page) {
  const text = page.revisions?.[0]?.slots?.main?.content ?? "";
  const ingredients = sectionLines(text, "Ingredients", /^\*+\s*/);
  const steps = sectionLines(text, "Procedure|Directions|Method|Preparation|Instructions", /^#+\s*/);
  const servingsText = summaryField(text, "Servings") ?? summaryField(text, "servings") ?? "";
  const servings = parseInt(servingsText.match(/\d+/)?.[0] ?? "", 10);
  return {
    id: "wikibooks-" + page.pageid,
    title: page.title.replace(/^Cookbook:/, ""),
    url: "https://en.wikibooks.org/wiki/" + encodeURIComponent(page.title.replace(/ /g, "_")),
    historyUrl: `https://en.wikibooks.org/w/index.php?title=${encodeURIComponent(page.title.replace(/ /g, "_"))}&action=history`,
    revision: page.revisions?.[0]?.revid,
    revisionDate: page.revisions?.[0]?.timestamp,
    summaryCategory: summaryField(text, "Category"),
    time: summaryField(text, "Time"),
    servingsText, servings: Number.isFinite(servings) ? servings : null,
    ingredients, steps,
  };
}

mkdirSync(CACHE, { recursive: true });
const byCategory = {};
const all = new Set();
for (const cat of CATEGORIES) {
  byCategory[cat] = await categoryMembers(cat);
  byCategory[cat].forEach((t) => all.add(t));
  console.log(`${cat}: ${byCategory[cat].length}`);
}
const titles = [...all].sort();
const pages = [];
for (let i = 0; i < titles.length; i += 50) {
  const j = await api({ action: "query", prop: "revisions", rvprop: "content|ids|timestamp", rvslots: "main", titles: titles.slice(i, i + 50).join("|") });
  pages.push(...(j.query?.pages ?? []));
}

const recipes = [];
for (const p of pages) {
  if (p.missing) continue;
  const r = parse(p);
  r.categories = Object.entries(byCategory).filter(([, ts]) => ts.includes(p.title)).map(([c]) => c);
  const withQty = r.ingredients.filter((l) => QTY.test(l)).length;
  // Keep only recipes we can calculate honestly: servings stated, steps present, nearly every ingredient has an amount.
  if (!r.servings || r.servings > 24 || r.steps.length < 2 || r.ingredients.length < 3 || r.ingredients.length > 18) continue;
  if (withQty < r.ingredients.length - 1) continue;
  recipes.push(r);
}
recipes.sort((a, b) => a.title.localeCompare(b.title));
writeFileSync(OUT, JSON.stringify(recipes, null, 1) + "\n");
console.log(`${pages.length} pages checked, ${recipes.length} usable recipes -> ${OUT}`);

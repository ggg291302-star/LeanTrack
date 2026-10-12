// Finds an openly licensed photo for each recipe on Wikimedia Commons (official API),
// downloads a 480-px-wide copy, and records the photographer and license for attribution.
// Accepted licenses only: public domain, CC0, CC BY, CC BY-SA. Anything else is skipped.
//
// Output: LeanTrack/Resources/RecipePhotos/<recipe id>.jpg and scripts/data/recipes/photos.json
// Usage:  node scripts/recipes/fetch-photos.mjs           (search + download)
//         node scripts/recipes/fetch-photos.mjs --list    (also print the candidates for review)
import { existsSync, mkdirSync, readFileSync, writeFileSync, createWriteStream, statSync, readdirSync, rmSync } from "node:fs";
import { createHash } from "node:crypto";
import { join } from "node:path";
import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";
import { ROOT, USER_AGENT, sleep } from "../lib/files.mjs";
import { PHOTO_CHOICES } from "./recipe-curation.mjs";

const API = "https://commons.wikimedia.org/w/api.php";
const CACHE = join(ROOT, "scripts", ".cache", "commons");
const OUT_DIR = join(ROOT, "LeanTrack", "Resources", "RecipePhotos");
const OUT_JSON = join(ROOT, "scripts", "data", "recipes", "photos.json");
const WIDTH = 480;
const LIST = process.argv.includes("--list");

const OK_LICENSE = /^(cc0|public domain|pd\b|pd-|cc by(-sa)? \d(\.\d)?)/i;

async function api(params) {
  const query = new URLSearchParams({ format: "json", formatversion: "2", ...params }).toString();
  const file = join(CACHE, createHash("sha1").update(query).digest("hex") + ".json");
  if (existsSync(file)) return JSON.parse(readFileSync(file, "utf8"));
  for (let attempt = 0; attempt < 5; attempt++) {
    await sleep(1500 * 2 ** attempt);
    const res = await fetch(`${API}?${query}`, { headers: { "User-Agent": USER_AGENT } });
    const text = await res.text();
    if (res.ok && text.startsWith("{")) { writeFileSync(file, text); return JSON.parse(text); }
  }
  throw new Error(`Commons API kept refusing: ${query}`);
}

const plain = (html) => (html ?? "").replace(/<[^>]+>/g, "").replace(/&amp;/g, "&").replace(/&quot;/g, '"').replace(/&#039;/g, "'").replace(/\s+/g, " ").trim();

function describe(page) {
  const ii = page.imageinfo?.[0];
  if (!ii) return null;
  const m = ii.extmetadata ?? {};
  const license = plain(m.LicenseShortName?.value);
  return {
    file: page.title.replace(/^File:/, ""),
    pageURL: ii.descriptionurl,
    thumbURL: ii.thumburl,
    width: ii.width, height: ii.height, mime: ii.mime,
    artist: plain(m.Artist?.value) || plain(m.Credit?.value) || "Unknown",
    license,
    licenseURL: m.LicenseUrl?.value ?? null,
    ok: OK_LICENSE.test(license) && /jpeg|png/.test(ii.mime) && ii.width >= 500 && ii.width / ii.height < 2.2 && ii.height / ii.width < 1.6,
  };
}

const IMAGE_PROPS = { prop: "imageinfo", iiprop: "url|extmetadata|size|mime", iiurlwidth: String(WIDTH), iiextmetadatafilter: "LicenseShortName|LicenseUrl|Artist|Credit" };

async function candidates(query) {
  const j = await api({ action: "query", generator: "search", gsrsearch: `${query} filetype:bitmap`, gsrnamespace: "6", gsrlimit: "10", ...IMAGE_PROPS });
  return (j.query?.pages ?? []).sort((a, b) => a.index - b.index).map(describe).filter(Boolean);
}

async function byFile(file) {
  const j = await api({ action: "query", titles: `File:${file}`, ...IMAGE_PROPS });
  return describe(j.query.pages[0]);
}

const defaultQuery = (title) => title
  .replace(/\([^)]*\)/g, "").replace(/\b(I{1,3}|IV|V)\b$/g, "").replace(/\b(\d+-Minute|Basic|Original|Homemade|Easy|Simple|Portable)\b/gi, "")
  .replace(/\s+/g, " ").trim();

async function download(url, dest) {
  if (existsSync(dest) && statSync(dest).size > 0) return;
  await sleep(1000);
  const res = await fetch(url, { headers: { "User-Agent": USER_AGENT } });
  if (!res.ok) throw new Error(`${res.status} downloading ${url}`);
  await pipeline(Readable.fromWeb(res.body), createWriteStream(dest));
}

mkdirSync(CACHE, { recursive: true });
mkdirSync(OUT_DIR, { recursive: true });
const { recipes } = JSON.parse(readFileSync(join(ROOT, "LeanTrack/Resources/Data/recipes.json"), "utf8"));
const previous = existsSync(OUT_JSON) ? JSON.parse(readFileSync(OUT_JSON, "utf8")) : {};
const photos = {};
const review = [];
for (const r of recipes) {
  const choice = PHOTO_CHOICES[r.id];
  if (choice === null) { review.push(`-- ${r.id} ${r.title}: no photo (icon instead)`); continue; }
  let pick;
  let list = [];
  if (typeof choice === "string" && choice.startsWith("File:")) {
    pick = await byFile(choice.slice(5));
    if (!pick?.ok) throw new Error(`Chosen file for ${r.id} is not usable: ${JSON.stringify(pick)}`);
  } else {
    const query = typeof choice === "string" ? choice : defaultQuery(r.title);
    list = await candidates(query);
    const index = typeof choice === "number" ? choice : 0;
    pick = list.filter((c) => c.ok)[index];
    if (LIST) review.push(`## ${r.id} "${r.title}" q="${query}"\n` + list.map((c, i) => `   ${c.ok ? "ok" : "--"} ${c.file} [${c.license}] ${c.width}x${c.height}`).join("\n"));
  }
  if (!pick) { review.push(`!! ${r.id} ${r.title}: no free photo found`); continue; }
  const dest = join(OUT_DIR, `${r.id}.jpg`);
  if (previous[r.id] && previous[r.id].file !== pick.file && existsSync(dest)) rmSync(dest); // a different photo was chosen
  await download(pick.thumbURL, dest);
  photos[r.id] = { image: `${r.id}.jpg`, file: pick.file, pageURL: pick.pageURL, artist: pick.artist, license: pick.license, licenseURL: pick.licenseURL };
}
// Remove photos of recipes that no longer have one.
for (const f of readdirSync(OUT_DIR)) if (!photos[f.replace(/\.jpg$/, "")]) rmSync(join(OUT_DIR, f));
writeFileSync(OUT_JSON, JSON.stringify(photos, null, 1) + "\n");
if (review.length) console.log(review.join("\n"));
const bytes = readdirSync(OUT_DIR).reduce((a, f) => a + statSync(join(OUT_DIR, f)).size, 0);
console.log(`${Object.keys(photos).length}/${recipes.length} recipes have a photo; ${(bytes / 1e6).toFixed(1)} MB`);

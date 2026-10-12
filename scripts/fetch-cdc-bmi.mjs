// Downloads the official CDC BMI-for-age data (ages 2–20, by sex and month) used for
// children's BMI percentiles: L, M, S (2000 CDC growth charts) plus sigma and P95
// (2022 CDC extended BMI-for-age charts for BMIs above the 95th percentile).
// Public domain (U.S. government work). Bundled unchanged.
//
// Usage:  node scripts/fetch-cdc-bmi.mjs
import { copyFileSync, mkdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { ROOT, cachedDownload } from "./lib/files.mjs";

const URL = "https://www.cdc.gov/growthcharts/data/extended-bmi/bmi-age-2022.csv";
const OUT = join(ROOT, "LeanTrack", "Resources", "Data", "cdc-bmi-for-age-2022.csv");

const file = await cachedDownload(URL, "cdc-bmi-age-2022.csv");
const lines = readFileSync(file, "utf8").trim().split(/\r?\n/);
const header = lines[0].split(",").map((h) => h.trim().replace(/^"|"$/g, "").toLowerCase());
for (const col of ["sex", "agemos", "l", "m", "s", "sigma", "p95"]) {
  if (!header.includes(col)) throw new Error(`CDC file is missing column "${col}". Header: ${header.join(", ")}`);
}
mkdirSync(join(ROOT, "LeanTrack", "Resources", "Data"), { recursive: true });
copyFileSync(file, OUT);
console.log(`Wrote ${OUT}: ${lines.length - 1} rows, columns: ${header.join(", ")}`);

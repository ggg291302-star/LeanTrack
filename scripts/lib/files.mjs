// Small helpers shared by the data scripts: cached downloads and a zip reader.
// No npm packages needed (Node 22+).
import { createWriteStream, existsSync, mkdirSync, readFileSync, renameSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { inflateRawSync } from "node:zlib";
import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";

export const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
export const CACHE = join(ROOT, "scripts", ".cache");

export const USER_AGENT = "LeanTrack-data-scripts/1.0 (personal, non-commercial; github.com/ggg291302-star/LeanTrack)";

/** Downloads `url` into scripts/.cache (once) and returns the local path. */
export async function cachedDownload(url, fileName = url.split("/").pop()) {
  mkdirSync(CACHE, { recursive: true });
  const dest = join(CACHE, fileName);
  if (existsSync(dest) && statSync(dest).size > 0) return dest;
  process.stdout.write(`Downloading ${url} ... `);
  const res = await fetch(url, { headers: { "User-Agent": USER_AGENT } });
  if (!res.ok) throw new Error(`Download failed (${res.status}) for ${url}`);
  const tmp = dest + ".part";
  await pipeline(Readable.fromWeb(res.body), createWriteStream(tmp));
  renameSync(tmp, dest);
  console.log(`${(statSync(dest).size / 1e6).toFixed(1)} MB`);
  return dest;
}

/** Reads every file in a .zip archive. Returns Map<name, Buffer>. */
export function readZip(path, wanted = () => true) {
  const buf = readFileSync(path);
  // Find the End Of Central Directory record (signature 0x06054b50).
  let eocd = -1;
  for (let i = buf.length - 22; i >= Math.max(0, buf.length - 65557); i--) {
    if (buf.readUInt32LE(i) === 0x06054b50) { eocd = i; break; }
  }
  if (eocd < 0) throw new Error(`Not a zip file: ${path}`);
  const count = buf.readUInt16LE(eocd + 10);
  let p = buf.readUInt32LE(eocd + 16);
  const files = new Map();
  for (let n = 0; n < count; n++) {
    if (buf.readUInt32LE(p) !== 0x02014b50) throw new Error("Bad zip central directory");
    const method = buf.readUInt16LE(p + 10);
    const compSize = buf.readUInt32LE(p + 20);
    const nameLen = buf.readUInt16LE(p + 28);
    const extraLen = buf.readUInt16LE(p + 30);
    const commentLen = buf.readUInt16LE(p + 32);
    const localOffset = buf.readUInt32LE(p + 42);
    const name = buf.toString("utf8", p + 46, p + 46 + nameLen);
    p += 46 + nameLen + extraLen + commentLen;
    if (name.endsWith("/") || !wanted(name)) continue;
    if (compSize === 0xffffffff || localOffset === 0xffffffff) throw new Error(`ZIP64 not supported: ${name}`);
    const lNameLen = buf.readUInt16LE(localOffset + 26);
    const lExtraLen = buf.readUInt16LE(localOffset + 28);
    const start = localOffset + 30 + lNameLen + lExtraLen;
    const data = buf.subarray(start, start + compSize);
    if (method === 0) files.set(name, Buffer.from(data));
    else if (method === 8) files.set(name, inflateRawSync(data));
    else throw new Error(`Unsupported zip compression ${method} for ${name}`);
  }
  return files;
}

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

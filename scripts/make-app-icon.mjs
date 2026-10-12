// Draws LeanTrack's original app icon (1024×1024 PNG) with no dependencies.
// Design: a green progress ring (like the Home calorie ring) around three
// macro bars (protein green, carbs blue, fat orange) on a near-black background.
//
// Usage:  node scripts/make-app-icon.mjs
import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { deflateSync } from "node:zlib";

const SIZE = 1024;
const SAMPLES = 4; // 4×4 supersampling for smooth edges
const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const out = join(root, "LeanTrack/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png");

const hex = (h) => [(h >> 16) & 255, (h >> 8) & 255, h & 255];
const TRACK = hex(0x2c2c2e);
const RING = hex(0x30d158);
const BARS = [hex(0x30d158), hex(0x4c74ff), hex(0xff9f0a)];

const cx = 512, cy = 512;
const ringRadius = 330, ringWidth = 92;
const sweep = (300 / 360) * Math.PI * 2; // clockwise from 12 o'clock

// Signed distances (negative = inside).
function ringTrack(x, y) {
  return Math.abs(Math.hypot(x - cx, y - cy) - ringRadius) - ringWidth / 2;
}

function ringArc(x, y) {
  const dx = x - cx, dy = y - cy;
  let a = Math.atan2(dx, -dy); // 0 at top, clockwise positive
  if (a < 0) a += Math.PI * 2;
  if (a <= sweep) return Math.abs(Math.hypot(dx, dy) - ringRadius) - ringWidth / 2;
  const capDist = (ang) => Math.hypot(x - (cx + ringRadius * Math.sin(ang)), y - (cy - ringRadius * Math.cos(ang)));
  return Math.min(capDist(0), capDist(sweep)) - ringWidth / 2;
}

function roundedRect(x, y, left, top, w, h, r) {
  const qx = Math.abs(x - (left + w / 2)) - (w / 2 - r);
  const qy = Math.abs(y - (top + h / 2)) - (h / 2 - r);
  return Math.hypot(Math.max(qx, 0), Math.max(qy, 0)) + Math.min(Math.max(qx, qy), 0) - r;
}

const barWidth = 70, barGap = 34, barBottom = 672;
const barHeights = [230, 320, 170];
const barsLeft = cx - (barWidth * 3 + barGap * 2) / 2;
const bars = barHeights.map((h, i) => ({
  left: barsLeft + i * (barWidth + barGap),
  top: barBottom - h,
  h,
  color: BARS[i],
}));

function background(y) {
  // Subtle vertical gradient: #1C1C1E at the top to #000000 at the bottom.
  const t = y / SIZE;
  const v = Math.round(0x1c * (1 - t) + 0x05 * t);
  return [v, v, Math.round(v * 1.07)];
}

function shade(x, y) {
  let color = background(y);
  if (ringTrack(x, y) <= 0) color = TRACK;
  if (ringArc(x, y) <= 0) color = RING;
  for (const b of bars) {
    if (roundedRect(x, y, b.left, b.top, barWidth, b.h, barWidth / 2) <= 0) color = b.color;
  }
  return color;
}

const raw = Buffer.alloc((SIZE * 3 + 1) * SIZE);
for (let y = 0; y < SIZE; y++) {
  const rowStart = y * (SIZE * 3 + 1);
  raw[rowStart] = 0; // PNG filter: none
  for (let x = 0; x < SIZE; x++) {
    let r = 0, g = 0, b = 0;
    for (let sy = 0; sy < SAMPLES; sy++) {
      for (let sx = 0; sx < SAMPLES; sx++) {
        const c = shade(x + (sx + 0.5) / SAMPLES, y + (sy + 0.5) / SAMPLES);
        r += c[0]; g += c[1]; b += c[2];
      }
    }
    const n = SAMPLES * SAMPLES, p = rowStart + 1 + x * 3;
    raw[p] = Math.round(r / n);
    raw[p + 1] = Math.round(g / n);
    raw[p + 2] = Math.round(b / n);
  }
}

// Minimal PNG writer (8-bit RGB, no alpha: iOS icons must be opaque).
const crcTable = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
function crc32(buf) {
  let c = 0xffffffff;
  for (const byte of buf) c = crcTable[(c ^ byte) & 255] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(SIZE, 0);
ihdr.writeUInt32BE(SIZE, 4);
ihdr[8] = 8; // bit depth
ihdr[9] = 2; // color type: RGB
const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk("IHDR", ihdr),
  chunk("IDAT", deflateSync(raw, { level: 9 })),
  chunk("IEND", Buffer.alloc(0)),
]);

mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, png);
console.log(`Wrote ${out} (${(png.length / 1024).toFixed(1)} KB)`);

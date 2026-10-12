"""Fills LeanTrack/App/BuildConfig.swift with the USDA key from the USDA_API_KEY environment
variable (a GitHub Actions secret). Runs on the build machine only; the change is never committed.
Without the secret (for example on pull requests from forks) the app falls back to USDA's DEMO_KEY."""
import os
import re

MASK = [0x5A, 0x13, 0xC7, 0x2E, 0x91, 0x48, 0xB3, 0x6D]
PATH = os.path.join("LeanTrack", "App", "BuildConfig.swift")

key = os.environ.get("USDA_API_KEY", "").strip()
if not key:
    print("USDA_API_KEY not set: the app will use USDA's shared DEMO_KEY.")
    raise SystemExit(0)

encoded = ", ".join(f"0x{b ^ MASK[i % len(MASK)]:02X}" for i, b in enumerate(key.encode("utf-8")))
with open(PATH, encoding="utf-8") as f:
    source = f.read()
updated, count = re.subn(r"static let usdaKeyBytes: \[UInt8\] = \[\]", f"static let usdaKeyBytes: [UInt8] = [{encoded}]", source)
if count != 1:
    raise SystemExit("BuildConfig.swift placeholder not found")
with open(PATH, "w", encoding="utf-8") as f:
    f.write(updated)
print(f"USDA key added to the build ({len(key)} characters).")

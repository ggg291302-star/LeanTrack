#!/usr/bin/env bash
# Runs the unit tests and UI tests on the booted simulator ($SIM_UDID),
# then collects the screenshots into build/screenshots/.
set -euo pipefail

: "${SIM_UDID:?SIM_UDID must be set (run boot-simulator.sh first)}"

mkdir -p build/screenshots
rm -rf build/TestResults.xcresult

# TEST_RUNNER_ variables are passed to the test process without the prefix.
set +e
TEST_RUNNER_LT_SCREENSHOT_DIR="$PWD/build/screenshots" \
xcodebuild test \
  -project LeanTrack.xcodeproj \
  -scheme LeanTrack \
  -destination "id=$SIM_UDID" \
  -derivedDataPath build/DerivedData-Tests \
  -resultBundlePath build/TestResults.xcresult \
  > build/test.log 2>&1
STATUS=$?
set -e

# Short summary in the job log: errors, each test case result, final verdict.
grep -E "error:|Test Case .*(passed|failed)|Executed [0-9]+ test|\*\* TEST" build/test.log || true

# Also export screenshot attachments from the result bundle (backup route).
if [ -d build/TestResults.xcresult ]; then
  mkdir -p build/attachments
  if xcrun xcresulttool export attachments --path build/TestResults.xcresult --output-path build/attachments >/dev/null 2>&1; then
    python3 - <<'PY'
import json, os, shutil
src = "build/attachments"
manifest = os.path.join(src, "manifest.json")
if os.path.exists(manifest):
    for test in json.load(open(manifest)):
        for a in test.get("attachments", []):
            name = a.get("suggestedHumanReadableName") or a["exportedFileName"]
            # "01-Home_0_<UUID>.png" -> "01-Home.png"
            base = name.split("_")[0]
            dest = os.path.join("build/screenshots", base + ".png")
            if not os.path.exists(dest):
                shutil.copy(os.path.join(src, a["exportedFileName"]), dest)
PY
  fi
fi

echo "Screenshots:"
ls -1 build/screenshots || true

if [ $STATUS -ne 0 ]; then
  echo "::error::Tests failed (exit $STATUS). Last 150 lines of the log:"
  tail -n 150 build/test.log
  exit $STATUS
fi

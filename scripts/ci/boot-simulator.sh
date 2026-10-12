#!/usr/bin/env bash
# Finds the requested iPhone simulator, boots it, and sets a clean status bar
# (9:41, full battery) for screenshots. Writes SIM_UDID to $GITHUB_ENV.
# Usage: boot-simulator.sh "iPhone 17 Pro" "26.5"
set -euo pipefail

DEVICE_NAME="$1"
OS_VERSION="$2"
RUNTIME_KEY="com.apple.CoreSimulator.SimRuntime.iOS-${OS_VERSION//./-}"

UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name, runtime = sys.argv[1], sys.argv[2]
devices = json.load(sys.stdin)["devices"].get(runtime, [])
match = [d["udid"] for d in devices if d["name"] == name]
print(match[0] if match else "")
' "$DEVICE_NAME" "$RUNTIME_KEY")

if [ -z "$UDID" ]; then
  echo "::error::Simulator '$DEVICE_NAME' with iOS $OS_VERSION not found. Available:"
  xcrun simctl list devices available
  exit 1
fi

echo "Using $DEVICE_NAME (iOS $OS_VERSION): $UDID"
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override \
  --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100

echo "SIM_UDID=$UDID" >> "${GITHUB_ENV:-/dev/null}"

#!/usr/bin/env bash
# Builds an unsigned Release LeanTrack.app for real iPhones and wraps it in an IPA.
# Sideloadly signs it with the owner's Apple ID when it installs it.
# Usage: build-ipa.sh <marketing-version> <build-number>
set -euo pipefail

VERSION="${1:-0.1}"
BUILD="${2:-1}"

mkdir -p build
set +e
xcodebuild build \
  -project LeanTrack.xcodeproj \
  -scheme LeanTrack \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  > build/ipa-build.log 2>&1
STATUS=$?
set -e

grep -E "error:|warning: .*/LeanTrack/|\*\* BUILD" build/ipa-build.log || true

if [ $STATUS -ne 0 ]; then
  echo "::error::Release build failed. Last 80 lines of the log:"
  tail -n 80 build/ipa-build.log
  exit 1
fi

APP="build/DerivedData/Build/Products/Release-iphoneos/LeanTrack.app"
test -d "$APP" || { echo "::error::$APP not found"; exit 1; }

rm -rf build/Payload build/LeanTrack.ipa
mkdir -p build/Payload
cp -R "$APP" build/Payload/
(cd build && zip -qry LeanTrack.ipa Payload)

echo "IPA: $(du -h build/LeanTrack.ipa | cut -f1)"
/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP/Info.plist"
/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Info.plist"
/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP/Info.plist"

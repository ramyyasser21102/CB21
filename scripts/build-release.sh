#!/bin/bash
# Builds a Release app, ad-hoc signs it and zips it as dist/CB21-<version>.zip.
# The app is not notarized (no paid developer account); see the README for how users open it.
set -euo pipefail
cd "$(dirname "$0")/.."

xcodegen generate
rm -rf build dist
xcodebuild -project CB21.xcodeproj -scheme CB21 -configuration Release \
  -derivedDataPath build -destination 'generic/platform=macOS' ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build | tail -n 5

APP="build/Build/Products/Release/CB21.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")

codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

mkdir -p dist
ZIP="dist/CB21-$VERSION.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
shasum -a 256 "$ZIP" | tee "$ZIP.sha256"
echo "Built $ZIP"

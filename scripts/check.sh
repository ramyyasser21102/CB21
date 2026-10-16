#!/bin/bash
# Runs the package tests and builds the app. Used locally and by CI.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f Package.swift ]; then
  echo "==> swift test"
  swift test
else
  echo "==> no Package.swift yet, skipping swift test"
fi

if [ -f project.yml ]; then
  echo "==> xcodegen"
  xcodegen generate
  echo "==> xcodebuild"
  xcodebuild -project CB21.xcodeproj -scheme CB21 -configuration Debug \
    -destination 'platform=macOS' build | tail -n 20
else
  echo "==> no project.yml yet, skipping xcodebuild"
fi

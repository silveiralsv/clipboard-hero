#!/bin/bash
# Builds a release binary and wraps it into build/ClipboardHero.app.
# Version comes from $VERSION, else the latest git tag (without the "v"), else 0.0.0.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)}"
VERSION="${VERSION:-0.0.0}"
APP=build/ClipboardHero.app

swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN/ClipboardHero" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
/usr/libexec/PlistBuddy \
    -c "Set :CFBundleShortVersionString $VERSION" \
    -c "Set :CFBundleVersion $VERSION" \
    "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "Built $APP ($VERSION)"

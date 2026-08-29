#!/bin/bash
# Builds ScreenShotClipboard.app next to this script. Needs the Command Line Tools only.
set -euo pipefail
cd "$(dirname "$0")"

APP="ScreenShotClipboard.app"
BINARY="$APP/Contents/MacOS/ScreenShotClipboard"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Universal, so a downloaded release runs on Intel Macs as well as Apple Silicon.
for ARCH in arm64 x86_64; do
	swiftc -O -target "$ARCH-apple-macos13.0" \
		-framework Cocoa -framework ServiceManagement \
		-o "$BINARY.$ARCH" Sources/*.swift
done
lipo -create -output "$BINARY" "$BINARY.arm64" "$BINARY.x86_64"
rm -f "$BINARY.arm64" "$BINARY.x86_64"

# Ad-hoc signature: without a stable identity macOS re-asks for Desktop access every launch.
codesign --force --sign - "$APP"

echo "Built $PWD/$APP"

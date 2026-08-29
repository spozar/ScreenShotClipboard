#!/bin/bash
# Builds ScreenShotClipboard.app next to this script. Needs the Command Line Tools only.
set -euo pipefail
cd "$(dirname "$0")"

APP="ScreenShotClipboard.app"
BINARY="$APP/Contents/MacOS/ScreenShotClipboard"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"

swiftc -O -target arm64-apple-macos13.0 \
	-framework Cocoa -framework ServiceManagement \
	-o "$BINARY" Sources/*.swift

# Ad-hoc signature: without a stable identity macOS re-asks for Desktop access every launch.
codesign --force --sign - "$APP"

echo "Built $PWD/$APP"

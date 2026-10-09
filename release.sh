#!/bin/bash
# Builds a signed, notarized ScreenShotClipboard.zip ready to upload to a release.
# Downloads of that zip open with a plain double click, no Gatekeeper warning.
#
# One-time setup (needs Apple Developer Program membership):
#   1. Install a "Developer ID Application" certificate in the login keychain
#      (Xcode > Settings > Accounts > Manage Certificates, or developer.apple.com).
#   2. Save notarization credentials under the profile name "notary", using an
#      app-specific password from appleid.apple.com:
#      xcrun notarytool store-credentials notary --apple-id you@example.com --team-id 99476Z45K6
set -euo pipefail
cd "$(dirname "$0")"

APP="ScreenShotClipboard.app"
ZIP="ScreenShotClipboard.zip"
PROFILE="notary"

fail() { echo "error: $*" >&2; exit 1; }

# Sign by SHA-1 rather than by name. The same certificate often shows up several times
# (login and System keychains), and a renewed certificate shares the old one's name.
IDENTITY=$(security find-identity -v -p codesigning \
	| awk '/"Developer ID Application: / {print $2; exit}')
[ -n "$IDENTITY" ] || fail "no valid Developer ID Application certificate in the keychain. See the top of this script."
IDENTITY_NAME=$(security find-identity -v -p codesigning | awk -F'"' -v h="$IDENTITY" '$0 ~ h {print $2; exit}')
echo "Signing as $IDENTITY_NAME ($IDENTITY)"

# Check the notary credentials before spending time on a build. This only reads the
# submission history, it submits nothing.
if ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
	fail "notarytool profile \"$PROFILE\" is missing or its credentials were rejected. Run:
  xcrun notarytool store-credentials $PROFILE --apple-id you@example.com --team-id 99476Z45K6"
fi

./build.sh

# Replace build.sh's ad-hoc signature. Notarization requires the hardened runtime and a
# secure timestamp. No entitlements: the app needs none of the runtime exceptions.
codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "Submitting to Apple, this usually takes a minute or two..."
RESULT=$(xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait --output-format json)
STATUS=$(plutil -extract status raw - <<<"$RESULT" 2>/dev/null || echo unknown)
if [ "$STATUS" != "Accepted" ]; then
	ID=$(plutil -extract id raw - <<<"$RESULT" 2>/dev/null || true)
	echo "$RESULT" >&2
	[ -n "$ID" ] && xcrun notarytool log "$ID" --keychain-profile "$PROFILE" >&2
	fail "notarization finished with status \"$STATUS\"."
fi

# Staple the notarization ticket into the app, then re-zip so the upload carries it.
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

spctl --assess --type exec -vv "$APP" || fail "Gatekeeper rejected $APP."
echo "Upload $PWD/$ZIP to the release."

#!/usr/bin/env bash
# Build, notarize, and package ClaudeUsage.app into a distributable DMG.
#
# One-time prerequisites:
#   1. Developer ID Application certificate in the login keychain
#      (Xcode > Settings > Accounts > Manage Certificates > + Developer ID Application).
#   2. notarytool credentials stored once via:
#        xcrun notarytool store-credentials "ClaudeUsage-notary" \
#          --apple-id <apple-id-email> \
#          --team-id 9EYB4D9GGQ \
#          --password <app-specific-password>
#   3. create-dmg installed:
#        brew install create-dmg
#
# Usage: scripts/release.sh

set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BUILD="$ROOT/build"
SCHEME="ClaudeUsage"
APP_NAME="ClaudeUsage"
APP_BUNDLE="$APP_NAME.app"
TEAM_ID="9EYB4D9GGQ"
NOTARY_PROFILE="ClaudeUsage-notary"

log()  { printf "\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n" "$*"; }
fail() { printf "\n\033[1;31mERROR:\033[0m %s\n" "$*" >&2; exit 1; }

command -v create-dmg >/dev/null || fail "create-dmg not installed. Run: brew install create-dmg"

cd "$ROOT"

log "Cleaning previous build artifacts"
rm -rf "$BUILD"
mkdir -p "$BUILD"

log "Writing ExportOptions.plist"
cat > "$BUILD/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>       <string>developer-id</string>
    <key>teamID</key>       <string>$TEAM_ID</string>
    <key>signingStyle</key> <string>automatic</string>
</dict>
</plist>
PLIST

log "Archiving (Release)"
xcodebuild -scheme "$SCHEME" -configuration Release \
  -archivePath "$BUILD/$APP_NAME.xcarchive" \
  -allowProvisioningUpdates \
  archive | tail -20

log "Exporting for Developer ID distribution"
xcodebuild -exportArchive \
  -archivePath "$BUILD/$APP_NAME.xcarchive" \
  -exportPath "$BUILD/export" \
  -exportOptionsPlist "$BUILD/ExportOptions.plist" \
  -allowProvisioningUpdates | tail -10

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" \
  "$BUILD/export/$APP_BUNDLE/Contents/Info.plist")
BUILD_NUM=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" \
  "$BUILD/export/$APP_BUNDLE/Contents/Info.plist")
log "Built $APP_NAME $VERSION ($BUILD_NUM)"

log "Zipping app for notarization"
ditto -c -k --keepParent "$BUILD/export/$APP_BUNDLE" "$BUILD/$APP_NAME.zip"

log "Submitting app to notarization (may take a few minutes)"
xcrun notarytool submit "$BUILD/$APP_NAME.zip" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

log "Stapling app"
xcrun stapler staple "$BUILD/export/$APP_BUNDLE"

log "Building DMG"
create-dmg \
  --volname "$APP_NAME" \
  --window-size 500 300 \
  --icon "$APP_BUNDLE" 100 100 \
  --app-drop-link 380 100 \
  "$BUILD/$APP_NAME-$VERSION.dmg" \
  "$BUILD/export/$APP_BUNDLE"

CERT=$(security find-identity -v -p codesigning \
  | awk -F '"' '/Developer ID Application/ {print $2; exit}')
[[ -n "$CERT" ]] || fail "No Developer ID Application certificate found in keychain"

log "Signing DMG with: $CERT"
codesign --sign "$CERT" "$BUILD/$APP_NAME-$VERSION.dmg"

log "Submitting DMG to notarization"
xcrun notarytool submit "$BUILD/$APP_NAME-$VERSION.dmg" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

log "Stapling DMG"
xcrun stapler staple "$BUILD/$APP_NAME-$VERSION.dmg"

log "Verifying Gatekeeper acceptance"
spctl --assess --type open --context context:primary-signature \
  --verbose=2 "$BUILD/$APP_NAME-$VERSION.dmg" || \
  fail "Gatekeeper rejected the DMG. Inspect notarytool log with: xcrun notarytool log <id> --keychain-profile $NOTARY_PROFILE"

log "Done: $BUILD/$APP_NAME-$VERSION.dmg"

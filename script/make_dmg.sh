#!/usr/bin/env bash
# Builds a Release PicFacet and packages it as build/PicFacet-<version>.dmg
# (the app plus an Applications shortcut to drag it onto).
#
# Signing:
#   - With a "Developer ID Application" certificate installed, the app is
#     exported for distribution. Set NOTARY_PROFILE to a notarytool keychain
#     profile (xcrun notarytool store-credentials) to notarize and staple too.
#   - Otherwise the app keeps its Apple Development signature: fine for your
#     own Macs, but other people's Macs will block it.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="PicFacet"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' PicFacet/Info.plist)"
BUILD_DIR="$ROOT_DIR/build/release"
ARCHIVE="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
STAGE_DIR="$BUILD_DIR/dmg"
DMG="$ROOT_DIR/build/$APP_NAME-$VERSION.dmg"

TEAM_ID="${TEAM_ID:-$(security find-certificate -c "Apple Development" -p 2>/dev/null \
  | openssl x509 -noout -subject 2>/dev/null | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p')}"
if [[ -z "$TEAM_ID" ]]; then
  echo "No Apple Development certificate found; set TEAM_ID." >&2
  exit 1
fi

rm -rf "${BUILD_DIR:?}"
mkdir -p "$BUILD_DIR"

echo "Archiving ${APP_NAME} ${VERSION} (team ${TEAM_ID})…"
xcodebuild -project PicFacet.xcodeproj -scheme PicFacet -configuration Release \
  -archivePath "$ARCHIVE" archive DEVELOPMENT_TEAM="$TEAM_ID" -quiet

DISTRIBUTION=0
if security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
  echo "Exporting with Developer ID…"
  cat > "$BUILD_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>developer-id</string>
    <key>teamID</key><string>$TEAM_ID</string>
    <key>signingStyle</key><string>automatic</string>
</dict>
</plist>
PLIST
  xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" -quiet
  DISTRIBUTION=1
else
  echo "No Developer ID certificate: packaging the development-signed app (runs on your Macs only)."
  mkdir -p "$EXPORT_DIR"
  ditto "$ARCHIVE/Products/Applications/$APP_NAME.app" "$EXPORT_DIR/$APP_NAME.app"
fi

echo "Building ${DMG}…"
mkdir -p "$STAGE_DIR"
ditto "$EXPORT_DIR/$APP_NAME.app" "$STAGE_DIR/$APP_NAME.app"
ln -s /Applications "$STAGE_DIR/Applications"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME $VERSION" -srcfolder "$STAGE_DIR" -ov -format UDZO "$DMG" -quiet

if [[ "$DISTRIBUTION" == "1" ]]; then
  codesign --sign "Developer ID Application" --timestamp "$DMG"
  if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    echo "Notarizing…"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
  else
    echo "Signed but not notarized: set NOTARY_PROFILE to notarize."
  fi
fi

echo "Done: $DMG ($(du -h "$DMG" | cut -f1))"

#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="PicFacet"
PROJECT_NAME="PicFacet.xcodeproj"
SCHEME="PicFacet"
CONFIGURATION="${CONFIGURATION:-Debug}"
BUNDLE_ID="com.picfacet.app"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA="$ROOT_DIR/build/DerivedData"
APP_BUNDLE="$DERIVED_DATA/Build/Products/$CONFIGURATION/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

cd "$ROOT_DIR"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

# Signing: background folder watching (the PicFacet Watcher login item) and the
# shared App Group need a signed build. Signs with your Apple Development
# certificate when one is installed; the team is read from it unless TEAM_ID is set.
#   UNSIGNED=1              build without signing (background watching off)
#   ALLOW_PROVISIONING=1    let Xcode create/refresh App IDs and profiles on your
#                           developer account (needed after adding a target or capability)
SIGN_ARGS=(CODE_SIGNING_ALLOWED=NO)
if [[ "${UNSIGNED:-0}" != "1" ]]; then
  TEAM_ID="${TEAM_ID:-$(security find-certificate -c "Apple Development" -p 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p')}"
  if [[ -n "$TEAM_ID" ]]; then
    SIGN_ARGS=(DEVELOPMENT_TEAM="$TEAM_ID")
    [[ "${ALLOW_PROVISIONING:-0}" == "1" ]] && SIGN_ARGS+=(-allowProvisioningUpdates)
    echo "Signing with Apple Development team $TEAM_ID"
  else
    echo "No Apple Development certificate found: building unsigned (background watching off)." >&2
  fi
fi

xcodebuild \
  -project "$PROJECT_NAME" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build \
  "${SIGN_ARGS[@]}"

# Install into /Applications and run from there. On macOS 27 the menu bar
# (and menu bar managers like Bartender) only handle status items properly for
# apps run from Applications, and a single installed copy keeps Finder's
# Quick Actions and the login item pointing at this build.
#   NO_INSTALL=1   run straight from the build folder instead
if [[ "${NO_INSTALL:-0}" != "1" ]]; then
  INSTALLED="/Applications/$APP_NAME.app"
  pkill -x PicFacetWatcher >/dev/null 2>&1 || true
  rm -rf "/Applications/PicFacet.app"
  ditto "$APP_BUNDLE" "$INSTALLED"
  APP_BUNDLE="$INSTALLED"
  APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
  echo "Installed $INSTALLED"
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac

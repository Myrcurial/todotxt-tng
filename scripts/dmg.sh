#!/usr/bin/env bash
# Packages build/TodoTxtTNG.app into a drag-to-Applications DMG.
# Uses only hdiutil (built into macOS). Works offline and on CI.
#
#   scripts/dmg.sh                 # builds the app, then the DMG
#   VERSION=0.2.0 scripts/dmg.sh   # sets the app version and names the file TodoTxtTNG-0.2.0.dmg
#   SKIP_BUILD=1 scripts/dmg.sh    # package the existing build/TodoTxtTNG.app as-is
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0}"
APP="build/TodoTxtTNG.app"
DMG="build/TodoTxtTNG-$VERSION.dmg"
STAGE="build/dmg-stage"

if [[ "${SKIP_BUILD:-0}" != 1 ]]; then VERSION="$VERSION" scripts/bundle.sh release; fi
[[ -d "$APP" ]] || { echo "missing $APP" >&2; exit 1; }

echo "==> staging"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> creating $DMG"
hdiutil create -volname "TodoTxtTNG $VERSION" -srcfolder "$STAGE" \
  -fs HFS+ -format UDZO -imagekey zlib-level=9 -ov "$DMG" >/dev/null
rm -rf "$STAGE"
hdiutil verify "$DMG" >/dev/null

echo "==> done: $DMG ($(du -h "$DMG" | cut -f1))"

#!/usr/bin/env bash
# Builds TodoTxtApp and wraps it into build/TodoTxtTNG.app with an Info.plist and
# ad-hoc code signing. Needs only the Command Line Tools (no Xcode, no network).
#
#   scripts/bundle.sh            # release build
#   scripts/bundle.sh debug      # debug build
#   scripts/bundle.sh --open     # build, then launch
set -euo pipefail

cd "$(dirname "$0")/.."
CONFIG=release
OPEN=0
for arg in "$@"; do
  case "$arg" in
    debug|release) CONFIG="$arg" ;;
    --open) OPEN=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

VERSION="${VERSION:-0.1.0}"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
APP="build/TodoTxtTNG.app"

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG" --product TodoTxtApp
BIN="$(swift build -c "$CONFIG" --show-bin-path)/TodoTxtApp"

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TodoTxtTNG"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

echo "==> ad-hoc signing"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"

echo "==> done: $APP ($VERSION build $BUILD)"
if [[ $OPEN == 1 ]]; then open "$APP"; fi

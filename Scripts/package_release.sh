#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$REPOSITORY_ROOT/dist"
APP="$DIST_DIR/LiveChurchTranslation.app"
RUNTIME="$REPOSITORY_ROOT/.artifacts/llama-b10549"
IDENTITY="${DEVELOPER_ID_APPLICATION:--}"
VERSION="${APP_VERSION:-1.0.0}"
BUILD_NUMBER="${APP_BUILD_NUMBER:-1}"

cd "$REPOSITORY_ROOT"
"$SCRIPT_DIR/check.sh"
swift build -c release --product LiveChurchTranslation
BIN_DIR="$(swift build -c release --show-bin-path)"
"$SCRIPT_DIR/fetch_llama_runtime.sh" "$RUNTIME"

mkdir -p "$DIST_DIR"
if [[ -e "$APP" ]]; then
  [[ "$APP" == "$REPOSITORY_ROOT/dist/LiveChurchTranslation.app" ]]
  rm -rf "$APP"
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers" "$APP/Contents/Resources"
ditto "$BIN_DIR/LiveChurchTranslation" "$APP/Contents/MacOS/LiveChurchTranslation"
ditto "$REPOSITORY_ROOT/Packaging/Info.plist" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
ditto "$REPOSITORY_ROOT/THIRD_PARTY_NOTICES.md" "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
ditto "$REPOSITORY_ROOT/Assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
ditto "$RUNTIME/LICENSE" "$APP/Contents/Resources/llama.cpp-LICENSE"

for file in "$RUNTIME"/llama-server "$RUNTIME"/*.dylib; do
  ditto "$file" "$APP/Contents/Helpers/$(basename "$file")"
done

SIGN_ARGS=(--force --sign "$IDENTITY")
if [[ "$IDENTITY" != "-" ]]; then
  SIGN_ARGS=(--force --options runtime --timestamp --sign "$IDENTITY")
fi
for library in "$APP"/Contents/Helpers/*.dylib; do
  codesign "${SIGN_ARGS[@]}" "$library"
done
codesign "${SIGN_ARGS[@]}" "$APP/Contents/Helpers/llama-server"
codesign "${SIGN_ARGS[@]}" \
  --entitlements "$REPOSITORY_ROOT/Packaging/LiveChurchTranslation.entitlements" "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"
plutil -lint "$APP/Contents/Info.plist"
otool -L "$APP/Contents/MacOS/LiveChurchTranslation"
echo "Created $APP"

#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$REPOSITORY_ROOT/dist"
APP="$DIST_DIR/Live Church Translation.app"
RUNTIME="$REPOSITORY_ROOT/.artifacts/llama-b10549"
MODELS="${RELEASE_MODELS_DIR:-$REPOSITORY_ROOT/.artifacts/release-models}"
IDENTITY="${DEVELOPER_ID_APPLICATION:--}"
VERSION="${APP_VERSION:-1.0.0}"
BUILD_NUMBER="${APP_BUILD_NUMBER:-1}"
RECLAIM_BUILD_SPACE="${RELEASE_RECLAIM_BUILD_SPACE:-0}"

"$SCRIPT_DIR/check_app_store_packaging.sh"
[[ "$VERSION" =~ ^[0-9]+([.][0-9]+){0,2}$ ]] \
  || { echo "APP_VERSION must contain one to three numeric components." >&2; exit 1; }
[[ "$BUILD_NUMBER" =~ ^[0-9]+([.][0-9]+){0,2}$ ]] \
  || { echo "APP_BUILD_NUMBER must contain one to three numeric components." >&2; exit 1; }
[[ "$RECLAIM_BUILD_SPACE" == "0" || "$RECLAIM_BUILD_SPACE" == "1" ]] \
  || { echo "RELEASE_RECLAIM_BUILD_SPACE must be 0 or 1." >&2; exit 1; }

if [[ "$IDENTITY" != "-" ]]; then
  MATCHING_IDENTITY="$({ security find-identity -v -p codesigning || true; } \
    | grep -F "$IDENTITY" | head -n 1 || true)"
  if [[ "$MATCHING_IDENTITY" != *"Developer ID Application:"* ]]; then
    echo "DEVELOPER_ID_APPLICATION must resolve to a Developer ID Application identity." >&2
    echo "Mac App Store Apple Distribution identities belong in archive_app_store.sh." >&2
    exit 1
  fi
else
  echo "WARNING: creating an ad-hoc engineering app, not a distributable release." >&2
fi

cd "$REPOSITORY_ROOT"
"$SCRIPT_DIR/check.sh"
swift build -c release --product LiveChurchTranslation
BIN_DIR="$(swift build -c release --show-bin-path)"
"$SCRIPT_DIR/fetch_llama_runtime.sh" "$RUNTIME"
"$SCRIPT_DIR/fetch_release_models.sh" "$MODELS"

mkdir -p "$DIST_DIR"
if [[ -e "$APP" ]]; then
  [[ "$APP" == "$REPOSITORY_ROOT/dist/Live Church Translation.app" ]]
  rm -rf "$APP"
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
ditto "$BIN_DIR/LiveChurchTranslation" "$APP/Contents/MacOS/LiveChurchTranslation"
strip -S "$APP/Contents/MacOS/LiveChurchTranslation"
while IFS= read -r rpath; do
  case "$rpath" in
    @loader_path | @executable_path)
      ;;
    *)
      install_name_tool -delete_rpath "$rpath" \
        "$APP/Contents/MacOS/LiveChurchTranslation"
      ;;
  esac
done < <(
  otool -l "$APP/Contents/MacOS/LiveChurchTranslation" \
    | awk '$1 == "cmd" && $2 == "LC_RPATH" { wanted = 1; next }
      wanted && $1 == "path" { print $2; wanted = 0 }'
)
ditto "$REPOSITORY_ROOT/Packaging/Info.plist" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Delete :CFBundleIconName' \
  "$APP/Contents/Info.plist" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIconLiveChurchTranslation' \
  "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"
ditto "$REPOSITORY_ROOT/THIRD_PARTY_NOTICES.md" "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
ditto "$REPOSITORY_ROOT/PRIVACY.md" "$APP/Contents/Resources/PRIVACY.md"
ditto "$REPOSITORY_ROOT/Assets/AppIconLiveChurchTranslation.icns" \
  "$APP/Contents/Resources/AppIconLiveChurchTranslation.icns"
ditto "$RUNTIME/LICENSE" "$APP/Contents/Resources/llama.cpp-LICENSE"
ditto "$REPOSITORY_ROOT/Packaging/PrivacyInfo.xcprivacy" \
  "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
ditto "$REPOSITORY_ROOT/Packaging/zh-Hans.lproj" \
  "$APP/Contents/Resources/zh-Hans.lproj"
ditto "$REPOSITORY_ROOT/Packaging/Licenses" \
  "$APP/Contents/Resources/Licenses"
ditto --clone "$MODELS" "$APP/Contents/Resources/Models"
"$SCRIPT_DIR/check_bundled_models.sh" "$APP"
"$SCRIPT_DIR/check_bundled_licenses.sh" "$APP/Contents/Resources/Licenses"

for file in "$RUNTIME"/llama-server "$RUNTIME"/*.dylib; do
  ditto "$file" "$APP/Contents/MacOS/$(basename "$file")"
done

SIGN_ARGS=(--force --sign "$IDENTITY")
if [[ "$IDENTITY" != "-" ]]; then
  SIGN_ARGS=(--force --options runtime --timestamp --sign "$IDENTITY")
fi
for library in "$APP"/Contents/MacOS/*.dylib; do
  codesign "${SIGN_ARGS[@]}" "$library"
done
codesign "${SIGN_ARGS[@]}" \
  --entitlements "$REPOSITORY_ROOT/Packaging/Helper.entitlements" \
  "$APP/Contents/MacOS/llama-server"
codesign "${SIGN_ARGS[@]}" \
  --entitlements "$REPOSITORY_ROOT/Packaging/LiveChurchTranslation.entitlements" "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"
plutil -lint "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Resources/PrivacyInfo.xcprivacy"
codesign -d --entitlements :- "$APP" >/dev/null
codesign -d --entitlements :- "$APP/Contents/MacOS/llama-server" >/dev/null
"$SCRIPT_DIR/check_bundled_models.sh" "$APP"
"$SCRIPT_DIR/audit_release_app.sh" "$APP" "$IDENTITY"
otool -L "$APP/Contents/MacOS/LiveChurchTranslation"
if [[ "$RECLAIM_BUILD_SPACE" == "1" && -e "$REPOSITORY_ROOT/.build" ]]; then
  BUILD_ROOT="$REPOSITORY_ROOT/.build"
  [[ "$BUILD_ROOT" == "$REPOSITORY_ROOT/.build" && ! -L "$BUILD_ROOT" ]]
  rm -rf "$BUILD_ROOT"
  echo "Removed transient Swift build products after packaging."
fi
echo "Created Developer ID/engineering artifact $APP"
echo "This artifact is not a Mac App Store archive or upload package."

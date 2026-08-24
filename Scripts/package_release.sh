#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$REPOSITORY_ROOT/dist"
APP="$DIST_DIR/Live Church Translation.app"
DSYM="$DIST_DIR/Live Church Translation.app.dSYM"
DSYM_ARCHIVE="$DIST_DIR/Live Church Translation.app.dSYM.zip"
DSYM_CHECKSUM="$DIST_DIR/Live Church Translation.app.dSYM.sha256"
DSYM_UUID_RECORD="$DIST_DIR/Live Church Translation.app.dSYM.uuid"
RUNTIME="$REPOSITORY_ROOT/.artifacts/llama-b10549"
MODELS="${RELEASE_MODELS_DIR:-$REPOSITORY_ROOT/.artifacts/release-models}"
IDENTITY="${DEVELOPER_ID_APPLICATION:--}"
VERSION="${APP_VERSION:-1.0.0}"
BUILD_NUMBER="${APP_BUILD_NUMBER:-1}"
RECLAIM_BUILD_SPACE="${RELEASE_RECLAIM_BUILD_SPACE:-0}"
DSYM_VERIFY_ROOT=""

cleanup_dsym_verification() {
  [[ -n "$DSYM_VERIFY_ROOT" ]] || return 0
  [[ "$DSYM_VERIFY_ROOT" == /tmp/live-church-dsym-verify.* \
    && -d "$DSYM_VERIFY_ROOT" && ! -L "$DSYM_VERIFY_ROOT" ]] \
    || { echo "Refusing to remove an unsafe dSYM verification directory." >&2; return 1; }
  rm -rf "$DSYM_VERIFY_ROOT"
  DSYM_VERIFY_ROOT=""
}
trap cleanup_dsym_verification EXIT

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
SOURCE_DSYM="$BIN_DIR/LiveChurchTranslation.dSYM"
[[ -d "$SOURCE_DSYM" && ! -L "$SOURCE_DSYM" ]] \
  || { echo "Release dSYM is missing or unsafe." >&2; exit 1; }
"$SCRIPT_DIR/fetch_llama_runtime.sh" "$RUNTIME"
"$SCRIPT_DIR/fetch_release_models.sh" "$MODELS"

mkdir -p "$DIST_DIR"
if [[ -e "$APP" ]]; then
  [[ "$APP" == "$REPOSITORY_ROOT/dist/Live Church Translation.app" ]]
  rm -rf "$APP"
fi
if [[ -e "$DSYM" ]]; then
  [[ "$DSYM" == "$REPOSITORY_ROOT/dist/Live Church Translation.app.dSYM" ]]
  rm -rf "$DSYM"
fi
rm -f "$DSYM_ARCHIVE" "$DSYM_CHECKSUM" "$DSYM_UUID_RECORD"
ditto "$SOURCE_DSYM" "$DSYM"
BUILD_UUID="$(dwarfdump --uuid "$BIN_DIR/LiveChurchTranslation" | awk 'NR == 1 { print $2 }')"
DSYM_UUID="$(dwarfdump --uuid "$DSYM" | awk 'NR == 1 { print $2 }')"
[[ -n "$BUILD_UUID" && "$DSYM_UUID" == "$BUILD_UUID" ]] \
  || { echo "Release dSYM UUID does not match the built executable." >&2; exit 1; }
ditto -c -k --keepParent "$DSYM" "$DSYM_ARCHIVE"
[[ -s "$DSYM_ARCHIVE" && ! -L "$DSYM_ARCHIVE" ]] \
  || { echo "Release dSYM archive was not created safely." >&2; exit 1; }
/usr/bin/unzip -t "$DSYM_ARCHIVE" >/dev/null
DSYM_VERIFY_ROOT="$(mktemp -d /tmp/live-church-dsym-verify.XXXXXX)"
ditto -x -k "$DSYM_ARCHIVE" "$DSYM_VERIFY_ROOT"
EXTRACTED_DSYM="$DSYM_VERIFY_ROOT/$(basename "$DSYM")"
[[ -d "$EXTRACTED_DSYM" && ! -L "$EXTRACTED_DSYM" \
  && -z "$(find "$EXTRACTED_DSYM" -type l -print -quit)" ]] \
  || { echo "Release dSYM archive contents are unsafe." >&2; exit 1; }
[[ "$(find "$DSYM_VERIFY_ROOT" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" == "1" ]] \
  || { echo "Release dSYM archive has unexpected top-level contents." >&2; exit 1; }
EXTRACTED_DSYM_UUID="$(dwarfdump --uuid "$EXTRACTED_DSYM" | awk 'NR == 1 { print $2 }')"
[[ "$EXTRACTED_DSYM_UUID" == "$DSYM_UUID" ]] \
  || { echo "Archived dSYM UUID does not match the built executable." >&2; exit 1; }
dwarfdump --verify "$EXTRACTED_DSYM" >/dev/null 2>&1 \
  || { echo "Archived dSYM DWARF verification failed." >&2; exit 1; }
cleanup_dsym_verification
DSYM_SHA="$(shasum -a 256 "$DSYM_ARCHIVE" | awk '{ print $1 }')"
printf '%s  %s\n' "$DSYM_SHA" "$(basename "$DSYM_ARCHIVE")" >"$DSYM_CHECKSUM"
printf '%s\n' "$DSYM_UUID" >"$DSYM_UUID_RECORD"
chmod 0600 "$DSYM_ARCHIVE" "$DSYM_CHECKSUM" "$DSYM_UUID_RECORD"
[[ -s "$DSYM_CHECKSUM" && ! -L "$DSYM_CHECKSUM" \
  && -s "$DSYM_UUID_RECORD" && ! -L "$DSYM_UUID_RECORD" ]] \
  || { echo "Release dSYM integrity records are missing or unsafe." >&2; exit 1; }
(cd "$DIST_DIR" && shasum -a 256 -c "$(basename "$DSYM_CHECKSUM")") >/dev/null
[[ "$(tr -d '\n' <"$DSYM_UUID_RECORD")" == "$DSYM_UUID" ]] \
  || { echo "Release dSYM UUID record is invalid." >&2; exit 1; }
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
PACKAGED_UUID="$(dwarfdump --uuid "$APP/Contents/MacOS/LiveChurchTranslation" \
  | awk 'NR == 1 { print $2 }')"
[[ "$PACKAGED_UUID" == "$DSYM_UUID" ]] \
  || { echo "Packaged executable UUID does not match the archived dSYM." >&2; exit 1; }
otool -L "$APP/Contents/MacOS/LiveChurchTranslation"
if [[ "$RECLAIM_BUILD_SPACE" == "1" && -e "$REPOSITORY_ROOT/.build" ]]; then
  BUILD_ROOT="$REPOSITORY_ROOT/.build"
  [[ "$BUILD_ROOT" == "$REPOSITORY_ROOT/.build" && ! -L "$BUILD_ROOT" ]]
  rm -rf "$BUILD_ROOT"
  echo "Removed transient Swift build products after packaging."
fi
echo "Created Developer ID/engineering artifact $APP"
echo "This artifact is not a Mac App Store archive or upload package."

#!/bin/bash
set -euo pipefail

fail() {
  echo "App Store packaging check failed: $*" >&2
  exit 1
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INFO="$REPOSITORY_ROOT/Packaging/Info.plist"
MAIN="$REPOSITORY_ROOT/Packaging/LiveChurchTranslation.entitlements"
HELPER="$REPOSITORY_ROOT/Packaging/Helper.entitlements"
PRIVACY="$REPOSITORY_ROOT/Packaging/PrivacyInfo.xcprivacy"
EXPORT_OPTIONS="$REPOSITORY_ROOT/Packaging/AppStoreExportOptions.plist"
RUNTIME_MANIFEST="$REPOSITORY_ROOT/Packaging/LlamaRuntime.sha256"
MODEL_SHA_MANIFEST="$REPOSITORY_ROOT/Packaging/ProductionModels.sha256"
MODEL_SIZE_MANIFEST="$REPOSITORY_ROOT/Packaging/ProductionModels.sizes"
LICENSE_MANIFEST="$REPOSITORY_ROOT/Packaging/LicenseFiles.sha256"
LICENSE_ROOT="$REPOSITORY_ROOT/Packaging/Licenses"
ZH_INFO="$REPOSITORY_ROOT/Packaging/zh-Hans.lproj/InfoPlist.strings"
ICON="$REPOSITORY_ROOT/Assets/AppIconQuiet.icns"
ICON_SOURCE="$REPOSITORY_ROOT/Assets/AppIconQuiet-1024.png"
ICON_CATALOG="$REPOSITORY_ROOT/Assets/AppIcon.xcassets"
ICON_SET="$ICON_CATALOG/AppIcon.appiconset"
ICON_CONTENTS="$ICON_SET/Contents.json"

plutil -lint "$INFO" "$MAIN" "$HELPER" "$PRIVACY" "$EXPORT_OPTIONS" >/dev/null
python3 -m json.tool "$ICON_CATALOG/Contents.json" >/dev/null
python3 -m json.tool "$ICON_CONTENTS" >/dev/null
[[ -f "$ICON" ]] || fail "release app icon is missing"
[[ -f "$ICON_SOURCE" ]] || fail "1024 px app icon source is missing"
[[ "$(file -b "$ICON")" == *"Mac OS X icon"* ]] || fail "release app icon is invalid"
[[ "$(sips -g pixelWidth "$ICON_SOURCE" | awk '/pixelWidth/ { print $2 }')" == "1024" ]] \
  || fail "app icon source width must be 1024 px"
[[ "$(sips -g pixelHeight "$ICON_SOURCE" | awk '/pixelHeight/ { print $2 }')" == "1024" ]] \
  || fail "app icon source height must be 1024 px"
ICON_VARIANTS=(
  AppIcon-16.png:16
  AppIcon-16@2x.png:32
  AppIcon-32.png:32
  AppIcon-32@2x.png:64
  AppIcon-128.png:128
  AppIcon-128@2x.png:256
  AppIcon-256.png:256
  AppIcon-256@2x.png:512
  AppIcon-512.png:512
  AppIcon-512@2x.png:1024
)
for variant in "${ICON_VARIANTS[@]}"; do
  filename="${variant%%:*}"
  pixels="${variant##*:}"
  image="$ICON_SET/$filename"
  [[ -f "$image" && ! -L "$image" ]] || fail "AppIcon variant is missing: $filename"
  [[ "$(sips -g pixelWidth "$image" | awk '/pixelWidth/ { print $2 }')" == "$pixels" ]] \
    || fail "AppIcon variant has the wrong width: $filename"
  [[ "$(sips -g pixelHeight "$image" | awk '/pixelHeight/ { print $2 }')" == "$pixels" ]] \
    || fail "AppIcon variant has the wrong height: $filename"
  rg -Fq "\"filename\" : \"$filename\"" "$ICON_CONTENTS" \
    || fail "AppIcon Contents.json omits $filename"
done
[[ "$(find "$ICON_SET" -maxdepth 1 -type f -name '*.png' | wc -l | tr -d ' ')" == "10" ]] \
  || fail "AppIcon set must contain exactly ten macOS PNG variants"
[[ "$(grep -c '\"idiom\" : \"mac\"' "$ICON_CONTENTS" | tr -d ' ')" == "10" ]] \
  || fail "AppIcon set must declare ten macOS image slots"
bash -n \
  "$SCRIPT_DIR/archive_app_store.sh" \
  "$SCRIPT_DIR/audit_app_store_archive.sh" \
  "$SCRIPT_DIR/audit_release_app.sh" \
  "$SCRIPT_DIR/check_app_store_packaging.sh" \
  "$SCRIPT_DIR/check_bundled_licenses.sh" \
  "$SCRIPT_DIR/check_bundled_models.sh" \
  "$SCRIPT_DIR/check_release_credentials.sh" \
  "$SCRIPT_DIR/check_release_models.sh" \
  "$SCRIPT_DIR/check_xcode_project.sh" \
  "$SCRIPT_DIR/create_dmg.sh" \
  "$SCRIPT_DIR/embed_app_store_runtime.sh" \
  "$SCRIPT_DIR/export_app_store.sh" \
  "$SCRIPT_DIR/fetch_llama_runtime.sh" \
  "$SCRIPT_DIR/fetch_release_models.sh" \
  "$SCRIPT_DIR/fetch_xcodegen.sh" \
  "$SCRIPT_DIR/generate_release_evidence.sh" \
  "$SCRIPT_DIR/generate_xcode_project.sh" \
  "$SCRIPT_DIR/notarize_release.sh" \
  "$SCRIPT_DIR/package_release.sh"

[[ "$(plist_value "$INFO" "CFBundleIdentifier")" == "com.shuoyan.LiveChurchTranslation" ]] \
  || fail "unexpected bundle ID"
[[ "$(plist_value "$INFO" "CFBundleDevelopmentRegion")" == "zh-Hans" ]] \
  || fail "Simplified Chinese must be the development language"
[[ -f "$ZH_INFO" ]] || fail "Simplified Chinese InfoPlist localization is missing"
plutil -lint "$ZH_INFO" >/dev/null || fail "Simplified Chinese InfoPlist localization is invalid"
[[ -n "$(plist_value "$INFO" "NSMicrophoneUsageDescription")" ]] \
  || fail "microphone usage description is missing"
[[ -n "$(plist_value "$INFO" "NSLocalNetworkUsageDescription")" ]] \
  || fail "local-network usage description is missing"
[[ "$(plist_value "$INFO" "NSBonjourServices:0")" == "_churchtranslate._tcp" ]] \
  || fail "Bonjour service is missing"
[[ "$(plist_value "$INFO" "ITSAppUsesNonExemptEncryption")" == "false" ]] \
  || fail "export-compliance declaration is missing"
[[ "$(plist_value "$INFO" "CFBundleIconName")" == "AppIcon" ]] \
  || fail "Info.plist does not identify the AppIcon asset"
[[ "$(plist_value "$INFO" "CFBundleShortVersionString")" == '$(MARKETING_VERSION)' ]] \
  || fail "marketing version must come from the archive build setting"
[[ "$(plist_value "$INFO" "CFBundleVersion")" == '$(CURRENT_PROJECT_VERSION)' ]] \
  || fail "build number must come from the archive build setting"

MAIN_KEYS=(
  com.apple.security.app-sandbox
  com.apple.security.device.microphone
  com.apple.security.device.audio-input
  com.apple.security.network.client
  com.apple.security.network.server
  com.apple.security.files.user-selected.read-only
)
for key in "${MAIN_KEYS[@]}"; do
  [[ "$(plist_value "$MAIN" "$key" || true)" == "true" ]] \
    || fail "main entitlement $key is missing"
done
[[ "$(grep -c '<key>' "$MAIN" | tr -d ' ')" == "${#MAIN_KEYS[@]}" ]] \
  || fail "main entitlement file contains an unreviewed key"

[[ "$(plist_value "$HELPER" "com.apple.security.app-sandbox")" == "true" ]] \
  || fail "helper App Sandbox entitlement is missing"
[[ "$(plist_value "$HELPER" "com.apple.security.inherit")" == "true" ]] \
  || fail "helper inheritance entitlement is missing"
[[ "$(grep -c '<key>' "$HELPER" | tr -d ' ')" == "2" ]] \
  || fail "helper may contain only sandbox and inheritance entitlements"

[[ "$(plist_value "$PRIVACY" "NSPrivacyTracking")" == "false" ]] \
  || fail "privacy manifest enables tracking"
PRIVACY_ARRAYS=(
  NSPrivacyTrackingDomains
  NSPrivacyCollectedDataTypes
)
for key in "${PRIVACY_ARRAYS[@]}"; do
  [[ "$(plutil -extract "$key" json -o - "$PRIVACY")" == "[]" ]] \
    || fail "privacy manifest $key must be empty for the audited architecture"
done
[[ "$(plist_value "$PRIVACY" \
  "NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPIType")" \
  == "NSPrivacyAccessedAPICategoryUserDefaults" ]] \
  || fail "privacy manifest must declare the UserDefaults API category"
[[ "$(plist_value "$PRIVACY" \
  "NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPITypeReasons:0")" == "CA92.1" ]] \
  || fail "privacy manifest must use the app-only UserDefaults reason"
[[ "$(plist_value "$PRIVACY" \
  "NSPrivacyAccessedAPITypes:1:NSPrivacyAccessedAPIType")" \
  == "NSPrivacyAccessedAPICategoryFileTimestamp" ]] \
  || fail "privacy manifest must declare the file-metadata API category"
[[ "$(plist_value "$PRIVACY" \
  "NSPrivacyAccessedAPITypes:1:NSPrivacyAccessedAPITypeReasons:0")" == "C617.1" ]] \
  || fail "privacy manifest must use the app-container file-metadata reason"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :NSPrivacyAccessedAPITypes' "$PRIVACY" \
  | grep -c 'Dict {' | tr -d ' ')" == "2" ]] \
  || fail "privacy manifest contains an unreviewed required-reason API category"
for index in 0 1; do
  [[ "$(/usr/libexec/PlistBuddy -c \
    "Print :NSPrivacyAccessedAPITypes:$index:NSPrivacyAccessedAPITypeReasons" "$PRIVACY" \
    | grep -c '[.]1' | tr -d ' ')" == "1" ]] \
    || fail "privacy manifest category contains an unreviewed reason"
  if /usr/libexec/PlistBuddy -c \
    "Print :NSPrivacyAccessedAPITypes:$index:NSPrivacyAccessedAPITypeReasons:1" \
    "$PRIVACY" >/dev/null 2>&1; then
    fail "privacy manifest category contains more than one reason"
  fi
done

[[ "$(plist_value "$EXPORT_OPTIONS" "method")" == "app-store-connect" ]] \
  || fail "export method is not App Store Connect"
[[ "$(plist_value "$EXPORT_OPTIONS" "destination")" == "export" ]] \
  || fail "export template must not upload"
[[ "$(plist_value "$EXPORT_OPTIONS" "teamID")" == "REPLACE_WITH_TEAM_ID" ]] \
  || fail "tracked export template must not contain a real team ID"
[[ "$(wc -l <"$RUNTIME_MANIFEST" | tr -d ' ')" == "12" ]] \
  || fail "pinned llama.cpp runtime manifest is incomplete"
[[ "$(wc -l <"$MODEL_SHA_MANIFEST" | tr -d ' ')" == "7" ]] \
  || fail "production model SHA manifest is incomplete"
[[ "$(wc -l <"$MODEL_SIZE_MANIFEST" | tr -d ' ')" == "7" ]] \
  || fail "production model size manifest is incomplete"
[[ "$(awk '{ total += $1 } END { print total }' "$MODEL_SIZE_MANIFEST")" \
  == "2120095795" ]] || fail "production model byte total changed without review"
[[ "$(wc -l <"$LICENSE_MANIFEST" | tr -d ' ')" == "8" ]] \
  || fail "third-party license manifest is incomplete"
"$SCRIPT_DIR/check_bundled_licenses.sh" "$LICENSE_ROOT"
awk 'length($1) != 64 || $2 !~ /^[A-Za-z0-9._\/-]+$/ { exit 1 }' "$MODEL_SHA_MANIFEST" \
  || fail "production model SHA manifest is malformed"
if [[ -d "$REPOSITORY_ROOT/.artifacts/llama-b10549" ]]; then
  (cd "$REPOSITORY_ROOT/.artifacts/llama-b10549" \
    && shasum -a 256 -c "$RUNTIME_MANIFEST" >/dev/null) \
    || fail "cached llama.cpp runtime differs from the pinned manifest"
fi
rg -Fq 'minimumXcodeGenVersion: 2.45.4' \
  "$REPOSITORY_ROOT/Packaging/XcodeGen/project.yml" \
  || fail "XcodeGen project version is not pinned"
rg -Fq '090ec29491aad50aec10631bf6e62253fed733c50f3aab0f5ffc86bc170bdbef' \
  "$SCRIPT_DIR/fetch_xcodegen.sh" || fail "XcodeGen archive checksum is not pinned"
MODEL_SOURCE_MANIFEST="$SCRIPT_DIR/release_model_sources.tsv"
RELEASE_WORKFLOW="$REPOSITORY_ROOT/.github/workflows/release.yml"
CI_WORKFLOW="$REPOSITORY_ROOT/.github/workflows/ci.yml"
[[ -f "$MODEL_SOURCE_MANIFEST" && ! -L "$MODEL_SOURCE_MANIFEST" ]] \
  || fail "release model source manifest is missing"
[[ "$(grep -vc '^#' "$MODEL_SOURCE_MANIFEST" | tr -d ' ')" == "7" ]] \
  || fail "release model source manifest must list seven artifacts"
rg -Fq '68818b2313fe77bd06f6a7c5068ff3ef59d02b8a' "$MODEL_SOURCE_MANIFEST" \
  || fail "Qwen release source is not revision-pinned"
rg -Fq '1cd5208700acedef4ef93019b6cfc148b8522d45' "$MODEL_SOURCE_MANIFEST" \
  || fail "Hy-MT2 release source is not revision-pinned"
[[ -f "$RELEASE_WORKFLOW" && ! -L "$RELEASE_WORKFLOW" ]] \
  || fail "GitHub Release workflow is missing"
if rg -n '^[[:space:]]*uses:[[:space:]]+[^[:space:]]+@(v[0-9]|main|master)([^0-9a-f]|$)' \
  "$RELEASE_WORKFLOW" >/dev/null; then
  fail "GitHub Release workflow contains a mutable Action reference"
fi
for workflow in "$CI_WORKFLOW" "$RELEASE_WORKFLOW"; do
  rg -Fq 'persist-credentials: false' "$workflow" \
    || fail "GitHub checkout credentials must not persist: $(basename "$workflow")"
done
rg -Fq 'environment: production-release' "$RELEASE_WORKFLOW" \
  || fail "formal release workflow must use the protected release environment"
rg -Fq 'git merge-base --is-ancestor' "$RELEASE_WORKFLOW" \
  || fail "formal release workflow must restrict tags to default-branch history"

EXECUTABLE_SCRIPTS=(
  archive_app_store.sh
  audit_app_store_archive.sh
  audit_release_app.sh
  check_app_store_packaging.sh
  check_bundled_licenses.sh
  check_bundled_models.sh
  check_release_credentials.sh
  check_release_models.sh
  check_xcode_project.sh
  create_dmg.sh
  embed_app_store_runtime.sh
  export_app_store.sh
  fetch_llama_runtime.sh
  fetch_release_models.sh
  fetch_xcodegen.sh
  generate_release_evidence.sh
  generate_xcode_project.sh
  notarize_release.sh
  package_release.sh
)
for name in "${EXECUTABLE_SCRIPTS[@]}"; do
  [[ -x "$SCRIPT_DIR/$name" ]] || fail "$name is not executable"
done
if rg -q 'Contents/Helpers' "$REPOSITORY_ROOT/Sources/TranslationHyMT2/README.md"; then
  fail "translation helper documentation still references Contents/Helpers"
fi

echo "App Store packaging source check: PASS"

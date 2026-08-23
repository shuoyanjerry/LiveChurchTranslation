#!/bin/bash
set -euo pipefail

fail() {
  echo "App Store archive audit failed: $*" >&2
  exit 1
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null
}

require_true() {
  local actual
  actual="$(plist_value "$1" "$2" || true)"
  [[ "$actual" == "true" ]] || fail "$3 is missing or false"
}

require_nonempty() {
  local actual
  actual="$(plist_value "$1" "$2" || true)"
  [[ -n "$actual" ]] || fail "$3 is missing"
}

extract_entitlements() {
  codesign -d --entitlements :- "$1" >"$2" 2>/dev/null \
    || fail "cannot read entitlements from $1"
  plutil -lint "$2" >/dev/null || fail "invalid signed entitlements on $1"
}

signature_details() {
  codesign -dv --verbose=4 "$1" 2>&1
}

require_distribution_signature() {
  local details
  details="$(signature_details "$1")"
  [[ "$details" != *"Developer ID Application:"* ]] \
    || fail "$1 has a Developer ID signature"
  if [[ "$details" != *"Authority=Apple Distribution:"* \
    && "$details" != *"Authority=Mac App Distribution:"* \
    && "$details" != *"Authority=3rd Party Mac Developer Application:"* ]]; then
    fail "$1 is not signed for Mac App Store distribution"
  fi
}

ARCHIVE="${1:-}"
[[ -n "$ARCHIVE" ]] || fail "usage: $0 /path/to/Application.xcarchive"
[[ -d "$ARCHIVE" ]] || fail "archive does not exist: $ARCHIVE"
[[ -f "$ARCHIVE/Info.plist" ]] || fail "archive Info.plist is missing"
plutil -lint "$ARCHIVE/Info.plist" >/dev/null || fail "archive Info.plist is invalid"

APPLICATIONS_DIR="$ARCHIVE/Products/Applications"
[[ -d "$APPLICATIONS_DIR" ]] || fail "Products/Applications is missing"
shopt -s nullglob
APPS=("$APPLICATIONS_DIR"/*.app)
shopt -u nullglob
[[ "${#APPS[@]}" -eq 1 ]] || fail "archive must contain exactly one app"
APP="${APPS[0]}"
CONTENTS="$APP/Contents"
INFO="$CONTENTS/Info.plist"
PRIVACY="$CONTENTS/Resources/PrivacyInfo.xcprivacy"
ICON="$CONTENTS/Resources/AppIcon.icns"
HELPER="$CONTENTS/MacOS/llama-server"
PROFILE="$CONTENTS/embedded.provisionprofile"

[[ -f "$INFO" ]] || fail "app Info.plist is missing"
[[ -f "$PRIVACY" ]] || fail "PrivacyInfo.xcprivacy is not in Contents/Resources"
[[ -f "$ICON" ]] || fail "release app icon is missing from Contents/Resources"
[[ -x "$HELPER" && ! -L "$HELPER" ]] \
  || fail "llama-server must be a non-symlink executable in Contents/MacOS"
[[ ! -e "$CONTENTS/Helpers/llama-server" ]] \
  || fail "legacy Contents/Helpers/llama-server must not be present"

plutil -lint "$INFO" "$PRIVACY" >/dev/null || fail "bundle plist validation failed"
require_nonempty "$INFO" "NSMicrophoneUsageDescription" "microphone usage description"
require_nonempty "$INFO" "NSLocalNetworkUsageDescription" "local-network usage description"
[[ "$(plist_value "$INFO" "NSBonjourServices:0" || true)" == "_churchtranslate._tcp" ]] \
  || fail "Bonjour service declaration is missing"
[[ "$(plist_value "$INFO" "CFBundleIconName" || true)" == "AppIcon" ]] \
  || fail "bundle does not identify the reviewed AppIcon asset"
[[ "$(plist_value "$INFO" "ITSAppUsesNonExemptEncryption" || true)" == "false" ]] \
  || fail "export-compliance declaration is missing or not false"
[[ "$(plist_value "$PRIVACY" "NSPrivacyTracking" || true)" == "false" ]] \
  || fail "privacy manifest must disable tracking"
[[ "$(plutil -extract NSPrivacyTrackingDomains json -o - "$PRIVACY")" == "[]" ]] \
  || fail "privacy manifest contains tracking domains"
[[ "$(plutil -extract NSPrivacyCollectedDataTypes json -o - "$PRIVACY")" == "[]" ]] \
  || fail "privacy manifest contains undeclared collected-data entries"
[[ "$(plist_value "$PRIVACY" \
  "NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPIType")" \
  == "NSPrivacyAccessedAPICategoryUserDefaults" ]] \
  || fail "privacy manifest is missing the UserDefaults API category"
[[ "$(plist_value "$PRIVACY" \
  "NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPITypeReasons:0")" == "CA92.1" ]] \
  || fail "privacy manifest is missing the app-only UserDefaults reason"
[[ "$(plist_value "$PRIVACY" \
  "NSPrivacyAccessedAPITypes:1:NSPrivacyAccessedAPIType")" \
  == "NSPrivacyAccessedAPICategoryFileTimestamp" ]] \
  || fail "privacy manifest is missing the file-metadata API category"
[[ "$(plist_value "$PRIVACY" \
  "NSPrivacyAccessedAPITypes:1:NSPrivacyAccessedAPITypeReasons:0")" == "C617.1" ]] \
  || fail "privacy manifest is missing the app-container file-metadata reason"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :NSPrivacyAccessedAPITypes' "$PRIVACY" \
  | grep -c 'Dict {' | tr -d ' ')" == "2" ]] \
  || fail "privacy manifest contains an unreviewed required-reason API category"
for index in 0 1; do
  if /usr/libexec/PlistBuddy -c \
    "Print :NSPrivacyAccessedAPITypes:$index:NSPrivacyAccessedAPITypeReasons:1" \
    "$PRIVACY" >/dev/null 2>&1; then
    fail "privacy manifest category contains more than one reason"
  fi
done

BUNDLE_ID="$(plist_value "$INFO" "CFBundleIdentifier")"
VERSION="$(plist_value "$INFO" "CFBundleShortVersionString")"
BUILD="$(plist_value "$INFO" "CFBundleVersion")"
[[ "$VERSION" != *'$('* && "$BUILD" != *'$('* ]] \
  || fail "version build settings were not resolved into Info.plist"
EXECUTABLE_NAME="$(plist_value "$INFO" "CFBundleExecutable")"
EXECUTABLE="$CONTENTS/MacOS/$EXECUTABLE_NAME"
[[ -x "$EXECUTABLE" ]] || fail "main executable is missing"

if [[ -n "${APP_STORE_BUNDLE_ID:-}" && "$BUNDLE_ID" != "$APP_STORE_BUNDLE_ID" ]]; then
  fail "bundle ID $BUNDLE_ID does not match APP_STORE_BUNDLE_ID"
fi
if [[ -n "${APP_VERSION:-}" && "$VERSION" != "$APP_VERSION" ]]; then
  fail "version $VERSION does not match APP_VERSION"
fi
if [[ -n "${APP_BUILD_NUMBER:-}" && "$BUILD" != "$APP_BUILD_NUMBER" ]]; then
  fail "build $BUILD does not match APP_BUILD_NUMBER"
fi

codesign --verify --deep --strict --verbose=2 "$APP" \
  || fail "bundle code-signature verification failed"
require_distribution_signature "$APP"
require_distribution_signature "$HELPER"

TEMP_DIR="$(mktemp -d /tmp/quiet-liturgy-store-audit.XXXXXX)"
trap 'rm -rf "$TEMP_DIR"' EXIT
MAIN_ENTITLEMENTS="$TEMP_DIR/main-entitlements.plist"
HELPER_ENTITLEMENTS="$TEMP_DIR/helper-entitlements.plist"
PROFILE_PLIST="$TEMP_DIR/profile.plist"
extract_entitlements "$APP" "$MAIN_ENTITLEMENTS"
extract_entitlements "$HELPER" "$HELPER_ENTITLEMENTS"

MAIN_KEYS=(
  com.apple.security.app-sandbox
  com.apple.security.device.microphone
  com.apple.security.device.audio-input
  com.apple.security.network.client
  com.apple.security.network.server
  com.apple.security.files.user-selected.read-only
)
for key in "${MAIN_KEYS[@]}"; do
  require_true "$MAIN_ENTITLEMENTS" "$key" "main entitlement $key"
done
[[ "$(plist_value "$MAIN_ENTITLEMENTS" "com.apple.security.get-task-allow" || true)" \
  != "true" ]] || fail "distribution app has get-task-allow"

require_true "$HELPER_ENTITLEMENTS" "com.apple.security.app-sandbox" \
  "helper App Sandbox entitlement"
require_true "$HELPER_ENTITLEMENTS" "com.apple.security.inherit" \
  "helper inheritance entitlement"
HELPER_KEY_COUNT="$(grep -c '<key>' "$HELPER_ENTITLEMENTS" | tr -d ' ')"
[[ "$HELPER_KEY_COUNT" == "2" ]] \
  || fail "helper must contain only App Sandbox and inheritance entitlements"

SIGNED_APP_ID="$(plist_value "$MAIN_ENTITLEMENTS" \
  "com.apple.application-identifier" || true)"
if [[ -z "$SIGNED_APP_ID" ]]; then
  SIGNED_APP_ID="$(plist_value "$MAIN_ENTITLEMENTS" "application-identifier" || true)"
fi

MAIN_SIGNATURE="$(signature_details "$APP")"
HELPER_SIGNATURE="$(signature_details "$HELPER")"
SIGNED_TEAM="$(awk -F= '/^TeamIdentifier=/ {print $2; exit}' <<<"$MAIN_SIGNATURE")"
HELPER_TEAM="$(awk -F= '/^TeamIdentifier=/ {print $2; exit}' <<<"$HELPER_SIGNATURE")"
[[ "$SIGNED_TEAM" =~ ^[A-Z0-9]{10}$ ]] || fail "app signature has no valid team ID"
[[ "$HELPER_TEAM" == "$SIGNED_TEAM" ]] || fail "helper signature team differs from app"
if [[ -n "$SIGNED_APP_ID" && "$SIGNED_APP_ID" != "$SIGNED_TEAM.$BUNDLE_ID" ]]; then
  fail "signed application identifier does not authorize $BUNDLE_ID"
fi
if [[ -n "${APP_STORE_TEAM_ID:-}" && "$SIGNED_TEAM" != "$APP_STORE_TEAM_ID" ]]; then
  fail "signature team $SIGNED_TEAM does not match APP_STORE_TEAM_ID"
fi

# macOS App Sandbox and Hardened Runtime entitlements are unrestricted. Apple
# therefore permits a Mac App Store app that claims no restricted entitlement to
# omit an embedded provisioning profile. If Xcode embeds one, audit its identity.
if [[ -e "$PROFILE" || -L "$PROFILE" ]]; then
  [[ -f "$PROFILE" && ! -L "$PROFILE" ]] \
    || fail "embedded provisioning profile is not a trusted regular file"
  security cms -D -i "$PROFILE" >"$PROFILE_PLIST" 2>/dev/null \
    || fail "cannot decode embedded provisioning profile"
  plutil -lint "$PROFILE_PLIST" >/dev/null || fail "provisioning profile is invalid"
  PROFILE_TEAM="$(plist_value "$PROFILE_PLIST" "TeamIdentifier:0")"
  [[ "$PROFILE_TEAM" == "$SIGNED_TEAM" ]] \
    || fail "provisioning profile team differs from app signature"
  PROFILE_APP_ID="$(plist_value "$PROFILE_PLIST" \
    "Entitlements:com.apple.application-identifier" || true)"
  if [[ -z "$PROFILE_APP_ID" ]]; then
    PROFILE_APP_ID="$(plist_value "$PROFILE_PLIST" \
      "Entitlements:application-identifier" || true)"
  fi
  if [[ -n "$PROFILE_APP_ID" && "$PROFILE_APP_ID" != "$SIGNED_TEAM.$BUNDLE_ID" ]]; then
    fail "provisioning profile does not authorize $BUNDLE_ID"
  fi
  if [[ -n "$SIGNED_APP_ID" && -n "$PROFILE_APP_ID" \
    && "$SIGNED_APP_ID" != "$PROFILE_APP_ID" ]]; then
    fail "signed application identifier does not match the profile"
  fi
  [[ "$(plist_value "$PROFILE_PLIST" \
    "Entitlements:com.apple.security.get-task-allow" || true)" != "true" ]] \
    || fail "distribution profile permits debugging"
fi

ARCHIVE_APP_PATH="$(plist_value "$ARCHIVE/Info.plist" \
  "ApplicationProperties:ApplicationPath" || true)"
[[ "$ARCHIVE_APP_PATH" == "Applications/$(basename "$APP")" ]] \
  || fail "archive ApplicationPath does not identify the audited app"

shopt -s nullglob
DYLIBS=("$CONTENTS/MacOS"/*.dylib)
shopt -u nullglob
EXPECTED_DYLIBS=(
  libllama-server-impl.dylib
  libllama-common.0.dylib
  libmtmd.0.dylib
  libllama.0.dylib
  libggml.0.dylib
  libggml-cpu.0.dylib
  libggml-blas.0.dylib
  libggml-metal.0.dylib
  libggml-rpc.0.dylib
  libggml-base.0.dylib
)
[[ "${#DYLIBS[@]}" -eq "${#EXPECTED_DYLIBS[@]}" ]] \
  || fail "bundle must contain exactly the pinned llama.cpp dylib set"
for name in "${EXPECTED_DYLIBS[@]}"; do
  [[ -f "$CONTENTS/MacOS/$name" && ! -L "$CONTENTS/MacOS/$name" ]] \
    || fail "bundled runtime member is missing or unsafe: $name"
done
[[ "$(lipo -archs "$EXECUTABLE")" == "arm64" ]] \
  || fail "main executable must contain only arm64"
[[ "$(lipo -archs "$HELPER")" == "arm64" ]] \
  || fail "translation helper must contain only arm64"
for library in "${DYLIBS[@]}"; do
  [[ ! -L "$library" ]] || fail "bundled dylib must not be a symlink: $library"
  [[ "$(lipo -archs "$library")" == "arm64" ]] \
    || fail "bundled dylib must contain only arm64: $library"
  codesign --verify --strict --verbose=2 "$library" \
    || fail "invalid dylib signature: $library"
  require_distribution_signature "$library"
done

echo "Mac App Store archive audit: PASS"
echo "Archive: $ARCHIVE"
echo "App: $APP"
echo "Bundle ID: $BUNDLE_ID"
echo "Version/build: $VERSION ($BUILD)"
echo "Team: $SIGNED_TEAM"
echo "Architectures: arm64"
echo "Main SHA-256: $(shasum -a 256 "$EXECUTABLE" | awk '{print $1}')"
echo "Helper SHA-256: $(shasum -a 256 "$HELPER" | awk '{print $1}')"
echo "Privacy manifest SHA-256: $(shasum -a 256 "$PRIVACY" | awk '{print $1}')"

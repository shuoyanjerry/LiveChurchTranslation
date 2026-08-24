#!/bin/bash
set -euo pipefail

fail() {
  echo "Mac App Store archive failed: $*" >&2
  exit 1
}

require_value() {
  [[ -n "$2" ]] || fail "set $1"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INFO_PLIST="$REPOSITORY_ROOT/Packaging/Info.plist"
ENTITLEMENTS="$REPOSITORY_ROOT/Packaging/LiveChurchTranslation.entitlements"
PROJECT="${APP_STORE_PROJECT:-}"
WORKSPACE="${APP_STORE_WORKSPACE:-}"
SCHEME="${APP_STORE_SCHEME:-LiveChurchTranslation}"
TEAM_ID="${APP_STORE_TEAM_ID:-}"
SIGNING_IDENTITY="${APP_STORE_SIGNING_IDENTITY:-Apple Distribution}"
BUNDLE_ID="${APP_STORE_BUNDLE_ID:-$(/usr/libexec/PlistBuddy \
  -c 'Print :CFBundleIdentifier' "$INFO_PLIST")}"
VERSION="${APP_VERSION:-1.0.0}"
BUILD_NUMBER="${APP_BUILD_NUMBER:-1}"
ARCHIVE="${APP_STORE_ARCHIVE_PATH:-$REPOSITORY_ROOT/dist/AppStore/LiveChurchTranslation.xcarchive}"

"$SCRIPT_DIR/check_app_store_packaging.sh"

if [[ -z "$PROJECT" && -z "$WORKSPACE" ]]; then
  PROJECT="$REPOSITORY_ROOT/LiveChurchTranslation.xcodeproj"
fi

if [[ -n "$PROJECT" && "$PROJECT" != /* ]]; then
  PROJECT="$REPOSITORY_ROOT/$PROJECT"
fi
if [[ -n "$WORKSPACE" && "$WORKSPACE" != /* ]]; then
  WORKSPACE="$REPOSITORY_ROOT/$WORKSPACE"
fi
if [[ "$ARCHIVE" != /* ]]; then
  ARCHIVE="$REPOSITORY_ROOT/$ARCHIVE"
fi

require_value APP_STORE_TEAM_ID "$TEAM_ID"
if [[ -n "$PROJECT" && -n "$WORKSPACE" ]]; then
  fail "set only one of APP_STORE_PROJECT or APP_STORE_WORKSPACE"
fi
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || fail "APP_STORE_TEAM_ID must be a 10-character team ID"
[[ "$BUNDLE_ID" =~ ^[A-Za-z0-9][A-Za-z0-9.-]+$ ]] || fail "invalid bundle ID"
[[ "$VERSION" =~ ^[0-9]+([.][0-9]+){0,2}$ ]] || fail "invalid marketing version"
[[ "$BUILD_NUMBER" =~ ^[0-9]+([.][0-9]+){0,2}$ ]] || fail "invalid build number"

TRACKED_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"
[[ "$BUNDLE_ID" == "$TRACKED_BUNDLE_ID" ]] \
  || fail "APP_STORE_BUNDLE_ID must match Packaging/Info.plist"
[[ ! -e "$ARCHIVE" ]] || fail "refusing to overwrite existing archive: $ARCHIVE"

CONTAINER_ARGS=()
if [[ -n "$PROJECT" ]]; then
  [[ -d "$PROJECT" && "$PROJECT" == *.xcodeproj ]] \
    || fail "APP_STORE_PROJECT is not an .xcodeproj directory: $PROJECT"
  "$SCRIPT_DIR/check_xcode_project.sh" "$PROJECT"
  CONTAINER_ARGS=(-project "$PROJECT")
else
  [[ -d "$WORKSPACE" && "$WORKSPACE" == *.xcworkspace ]] \
    || fail "APP_STORE_WORKSPACE is not an .xcworkspace directory: $WORKSPACE"
  CONTAINER_ARGS=(-workspace "$WORKSPACE")
fi

if ! XCODE_VERSION="$(xcodebuild -version 2>&1)"; then
  fail "full Xcode is required; select it with xcode-select before archiving"
fi
XCODE_MAJOR="$(echo "$XCODE_VERSION" | awk '/^Xcode / {split($2, value, "."); print value[1]}')"
[[ -n "$XCODE_MAJOR" && "$XCODE_MAJOR" -ge 16 ]] \
  || fail "Xcode 16.4 or newer is required by this project"
if [[ "$XCODE_MAJOR" == "16" ]]; then
  XCODE_MINOR="$(echo "$XCODE_VERSION" | awk '/^Xcode / {split($2, value, "."); print value[2]}')"
  [[ "${XCODE_MINOR:-0}" -ge 4 ]] || fail "Xcode 16.4 or newer is required"
fi

IDENTITY_LINE="$({ security find-identity -v -p codesigning || true; } \
  | grep -F "$SIGNING_IDENTITY" | head -n 1 || true)"
if [[ "$IDENTITY_LINE" != *"Apple Distribution:"* \
  && "$IDENTITY_LINE" != *"Mac App Distribution:"* \
  && "$IDENTITY_LINE" != *"3rd Party Mac Developer Application:"* ]]; then
  fail "APP_STORE_SIGNING_IDENTITY does not resolve to an App Store distribution identity"
fi

PROVISIONING_ARGS=()
if [[ "${APP_STORE_ALLOW_PROVISIONING_UPDATES:-0}" == "1" ]]; then
  PROVISIONING_ARGS=(-allowProvisioningUpdates)
fi

COMMON_ARGS=(
  "${CONTAINER_ARGS[@]}"
  -scheme "$SCHEME"
  -configuration Release
  -destination "generic/platform=macOS"
  DEVELOPMENT_TEAM="$TEAM_ID"
  CODE_SIGN_STYLE=Automatic
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY"
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID"
  MARKETING_VERSION="$VERSION"
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
  GENERATE_INFOPLIST_FILE=NO
  INFOPLIST_FILE="$INFO_PLIST"
  CODE_SIGN_ENTITLEMENTS="$ENTITLEMENTS"
  ENABLE_APP_SANDBOX=YES
  ENABLE_HARDENED_RUNTIME=YES
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES
)

SETTINGS_LOG="$(mktemp /tmp/live-church-translation-build-settings.XXXXXX)"
trap 'rm -f "$SETTINGS_LOG"' EXIT
xcodebuild "${COMMON_ARGS[@]}" -showBuildSettings >"$SETTINGS_LOG"
grep -Eq 'PRODUCT_TYPE = com[.]apple[.]product-type[.]application$' "$SETTINGS_LOG" \
  || fail "scheme does not expose a macOS application target"
grep -Eq 'WRAPPER_EXTENSION = app$' "$SETTINGS_LOG" \
  || fail "scheme does not produce an app bundle"

cd "$REPOSITORY_ROOT"
"$SCRIPT_DIR/check.sh"
"$SCRIPT_DIR/fetch_llama_runtime.sh"
"$SCRIPT_DIR/fetch_release_models.sh"
mkdir -p "$(dirname "$ARCHIVE")"
BUILD_LOG="$ARCHIVE.build.log"
echo "$XCODE_VERSION"
echo "Archiving $BUNDLE_ID $VERSION ($BUILD_NUMBER) with team $TEAM_ID"
xcodebuild "${COMMON_ARGS[@]}" \
  -archivePath "$ARCHIVE" \
  "${PROVISIONING_ARGS[@]}" \
  archive | tee "$BUILD_LOG"

export APP_STORE_BUNDLE_ID="$BUNDLE_ID"
export APP_STORE_TEAM_ID="$TEAM_ID"
export APP_VERSION="$VERSION"
export APP_BUILD_NUMBER="$BUILD_NUMBER"
AUDIT_LOG="$ARCHIVE.audit.txt"
"$SCRIPT_DIR/audit_app_store_archive.sh" "$ARCHIVE" | tee "$AUDIT_LOG"
echo "Created audited Mac App Store archive: $ARCHIVE"
echo "Archive log: $BUILD_LOG"
echo "Audit report: $AUDIT_LOG"
echo "Nothing has been exported or uploaded."

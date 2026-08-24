#!/bin/bash
set -euo pipefail

fail() {
  echo "Mac App Store export failed: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARCHIVE="${APP_STORE_ARCHIVE_PATH:-$REPOSITORY_ROOT/dist/AppStore/LiveChurchTranslation.xcarchive}"
TEAM_ID="${APP_STORE_TEAM_ID:-}"
SIGNING_STYLE="${APP_STORE_SIGNING_STYLE:-automatic}"
TEMPLATE="$REPOSITORY_ROOT/Packaging/AppStoreExportOptions.plist"

"$SCRIPT_DIR/check_app_store_packaging.sh"

if [[ "$ARCHIVE" != /* ]]; then
  ARCHIVE="$REPOSITORY_ROOT/$ARCHIVE"
fi

[[ -d "$ARCHIVE" ]] || fail "archive does not exist: $ARCHIVE"
[[ "$TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] || fail "set a valid APP_STORE_TEAM_ID"
[[ "$SIGNING_STYLE" == "automatic" || "$SIGNING_STYLE" == "manual" ]] \
  || fail "APP_STORE_SIGNING_STYLE must be automatic or manual"
plutil -lint "$TEMPLATE" >/dev/null || fail "export options template is invalid"
if ! XCODE_VERSION="$(xcodebuild -version 2>&1)"; then
  fail "full Xcode is required; select it with xcode-select before exporting"
fi

"$SCRIPT_DIR/audit_app_store_archive.sh" "$ARCHIVE"

ARCHIVE_INFO="$ARCHIVE/Info.plist"
BUNDLE_ID="$(/usr/libexec/PlistBuddy \
  -c 'Print :ApplicationProperties:CFBundleIdentifier' "$ARCHIVE_INFO")"
VERSION="$(/usr/libexec/PlistBuddy \
  -c 'Print :ApplicationProperties:CFBundleShortVersionString' "$ARCHIVE_INFO")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy \
  -c 'Print :ApplicationProperties:CFBundleVersion' "$ARCHIVE_INFO")"
EXPORT_DIR="${APP_STORE_EXPORT_PATH:-$REPOSITORY_ROOT/dist/AppStore/Export-$VERSION-$BUILD_NUMBER}"
if [[ "$EXPORT_DIR" != /* ]]; then
  EXPORT_DIR="$REPOSITORY_ROOT/$EXPORT_DIR"
fi
[[ ! -e "$EXPORT_DIR" ]] || fail "refusing to overwrite existing export: $EXPORT_DIR"

TEMP_DIR="$(mktemp -d /tmp/live-church-translation-store-export.XXXXXX)"
OPTIONS="$TEMP_DIR/ExportOptions.plist"
trap 'rm -rf "$TEMP_DIR"' EXIT
ditto "$TEMPLATE" "$OPTIONS"
/usr/libexec/PlistBuddy -c "Set :teamID $TEAM_ID" "$OPTIONS"
/usr/libexec/PlistBuddy -c "Set :signingStyle $SIGNING_STYLE" "$OPTIONS"

if [[ "$SIGNING_STYLE" == "manual" ]]; then
  PROFILE="${APP_STORE_PROVISIONING_PROFILE:-}"
  APP_IDENTITY="${APP_STORE_SIGNING_IDENTITY:-}"
  INSTALLER_IDENTITY="${APP_STORE_INSTALLER_SIGNING_IDENTITY:-}"
  [[ -n "$PROFILE" ]] || fail "manual export requires APP_STORE_PROVISIONING_PROFILE"
  [[ -n "$APP_IDENTITY" ]] || fail "manual export requires APP_STORE_SIGNING_IDENTITY"
  [[ -n "$INSTALLER_IDENTITY" ]] \
    || fail "manual export requires APP_STORE_INSTALLER_SIGNING_IDENTITY"
  [[ "$PROFILE" != *$'\n'* && "$APP_IDENTITY" != *$'\n'* \
    && "$INSTALLER_IDENTITY" != *$'\n'* ]] || fail "signing values must be single-line"
  /usr/libexec/PlistBuddy -c 'Add :provisioningProfiles dict' "$OPTIONS"
  /usr/libexec/PlistBuddy \
    -c "Add :provisioningProfiles:$BUNDLE_ID string $PROFILE" "$OPTIONS"
  /usr/libexec/PlistBuddy -c "Add :signingCertificate string $APP_IDENTITY" "$OPTIONS"
  /usr/libexec/PlistBuddy \
    -c "Add :installerSigningCertificate string $INSTALLER_IDENTITY" "$OPTIONS"
fi
plutil -lint "$OPTIONS" >/dev/null || fail "rendered export options are invalid"

PROVISIONING_ARGS=()
if [[ "${APP_STORE_ALLOW_PROVISIONING_UPDATES:-0}" == "1" ]]; then
  PROVISIONING_ARGS=(-allowProvisioningUpdates)
fi

mkdir -p "$(dirname "$EXPORT_DIR")"
EXPORT_LOG="$EXPORT_DIR.log"
echo "$XCODE_VERSION"
echo "Exporting $BUNDLE_ID $VERSION ($BUILD_NUMBER) for team $TEAM_ID"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$OPTIONS" \
  "${PROVISIONING_ARGS[@]}" | tee "$EXPORT_LOG"

shopt -s nullglob
PACKAGES=("$EXPORT_DIR"/*.pkg)
shopt -u nullglob
[[ "${#PACKAGES[@]}" -eq 1 ]] \
  || fail "App Store Connect export must contain exactly one pkg"
PACKAGE="${PACKAGES[0]}"
PACKAGE_SIGNATURE="$(pkgutil --check-signature "$PACKAGE" 2>&1)" \
  || fail "exported package signature is invalid"
if [[ "$PACKAGE_SIGNATURE" != *"Mac Installer Distribution:"* \
  && "$PACKAGE_SIGNATURE" != *"3rd Party Mac Developer Installer:"* ]]; then
  fail "exported package is not signed with a Mac App Store installer identity"
fi

EXPANDED_PACKAGE="$TEMP_DIR/ExpandedPackage"
pkgutil --expand-full "$PACKAGE" "$EXPANDED_PACKAGE" \
  || fail "cannot expand exported package for audit"
EXPORTED_APPS=()
while IFS= read -r -d '' candidate; do
  EXPORTED_APPS+=("$candidate")
done < <(find "$EXPANDED_PACKAGE" -type d -name '*.app' -print0)
[[ "${#EXPORTED_APPS[@]}" -eq 1 ]] \
  || fail "exported package must contain exactly one app"
EXPORTED_ARCHIVE="$TEMP_DIR/Exported.xcarchive"
mkdir -p "$EXPORTED_ARCHIVE/Products/Applications"
ditto "$ARCHIVE_INFO" "$EXPORTED_ARCHIVE/Info.plist"
ditto "${EXPORTED_APPS[0]}" \
  "$EXPORTED_ARCHIVE/Products/Applications/$(basename "${EXPORTED_APPS[0]}")"
APP_STORE_BUNDLE_ID="$BUNDLE_ID" APP_STORE_TEAM_ID="$TEAM_ID" \
APP_VERSION="$VERSION" APP_BUILD_NUMBER="$BUILD_NUMBER" \
  "$SCRIPT_DIR/audit_app_store_archive.sh" "$EXPORTED_ARCHIVE"

RENDERED_OPTIONS="$EXPORT_DIR.ExportOptions.plist"
ditto "$OPTIONS" "$RENDERED_OPTIONS"
chmod 0644 "$RENDERED_OPTIONS"
echo "$PACKAGE_SIGNATURE"
echo "Package SHA-256: $(shasum -a 256 "$PACKAGE" | awk '{print $1}')"
echo "Created Mac App Store export: $PACKAGE"
echo "Export log: $EXPORT_LOG"
echo "Resolved export options: $RENDERED_OPTIONS"
echo "Nothing has been uploaded. Validate in Organizer or Transporter before upload."

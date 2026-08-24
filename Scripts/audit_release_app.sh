#!/bin/bash
set -euo pipefail

fail() {
  echo "Release app audit failed: $*" >&2
  exit 1
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP="${1:-}"
IDENTITY="${2:-${DEVELOPER_ID_APPLICATION:--}}"
RUNTIME_MANIFEST="$REPOSITORY_ROOT/Packaging/LlamaRuntime.sha256"

[[ -n "$APP" ]] || fail "usage: $0 /path/to/Application.app [signing-identity-or--]"
[[ -d "$APP" && ! -L "$APP" && "$APP" == *.app ]] || fail "app bundle is missing or unsafe"
[[ "$(basename "$APP")" == "Live Church Translation.app" ]] \
  || fail "app artifact must be named Live Church Translation.app"
CONTENTS="$APP/Contents"
MAIN="$CONTENTS/MacOS/LiveChurchTranslation"
HELPER="$CONTENTS/MacOS/llama-server"
MODELS="$CONTENTS/Resources/Models"
INFO="$CONTENTS/Info.plist"
PRIVACY="$CONTENTS/Resources/PrivacyInfo.xcprivacy"
ENTITLEMENTS="$(mktemp "${TMPDIR:-/tmp}/church-release-entitlements.XXXXXX")"
trap 'rm -f "$ENTITLEMENTS"' EXIT

[[ -x "$MAIN" && ! -L "$MAIN" ]] || fail "main executable is missing"
[[ -x "$HELPER" && ! -L "$HELPER" ]] || fail "llama-server is missing"
[[ ! -e "$CONTENTS/Helpers/llama-server" ]] || fail "legacy helper path is present"
[[ -f "$INFO" && -f "$PRIVACY" ]] || fail "required bundle metadata is missing"
plutil -lint "$INFO" "$PRIVACY" >/dev/null || fail "bundle metadata is invalid"
[[ "$(plist_value "$INFO" "CFBundleName" || true)" == "Live Church Translation" ]] \
  || fail "CFBundleName must be Live Church Translation"
[[ "$(plist_value "$INFO" "CFBundleDisplayName" || true)" == "Live Church Translation" ]] \
  || fail "CFBundleDisplayName must be Live Church Translation"
[[ -n "$(plist_value "$INFO" "NSLocalNetworkUsageDescription" || true)" ]] \
  || fail "local-network usage description is missing"
[[ "$(plutil -extract NSAppTransportSecurity json -o - "$INFO")" \
  == '{"NSAllowsLocalNetworking":true}' ]] \
  || fail "ATS must allow only local networking without broad cleartext exceptions"
[[ "$(plutil -extract NSBonjourServices json -o - "$INFO")" \
  == '["_churchtranslate._tcp"]' ]] \
  || fail "Bonjour must declare only the reviewed reader service"
[[ "$(lipo -archs "$MAIN")" == "arm64" ]] || fail "main executable must be arm64-only"
[[ "$(lipo -archs "$HELPER")" == "arm64" ]] || fail "llama-server must be arm64-only"

"$SCRIPT_DIR/check_release_models.sh" "$MODELS"
"$SCRIPT_DIR/check_bundled_licenses.sh" "$CONTENTS/Resources/Licenses"

expected_dylibs=0
while read -r expected_sha runtime_name; do
  [[ -n "$expected_sha" && -n "$runtime_name" ]] || fail "invalid runtime manifest row"
  if [[ "$runtime_name" == "LICENSE" ]]; then
    bundled="$CONTENTS/Resources/llama.cpp-LICENSE"
    [[ "$(shasum -a 256 "$bundled" | awk '{print $1}')" == "$expected_sha" ]] \
      || fail "runtime license SHA-256 mismatch"
  else
    bundled="$CONTENTS/MacOS/$runtime_name"
  fi
  [[ -f "$bundled" && ! -L "$bundled" ]] || fail "missing runtime member: $runtime_name"
  # Mach-O hashes change when pinned inputs receive their release signatures. The
  # fetch/embed steps verify pre-signing hashes; this post-signing audit verifies
  # inventory, architecture, signature validity, and signing-team continuity.
  if [[ "$runtime_name" == *.dylib ]]; then
    expected_dylibs=$((expected_dylibs + 1))
    [[ "$(lipo -archs "$bundled")" == "arm64" ]] \
      || fail "runtime library must be arm64-only: $runtime_name"
    codesign --verify --strict --verbose=2 "$bundled" \
      || fail "runtime library signature is invalid: $runtime_name"
  fi
done <"$RUNTIME_MANIFEST"

actual_dylibs="$(find "$CONTENTS/MacOS" -maxdepth 1 -type f -name '*.dylib' \
  | wc -l | tr -d ' ')"
[[ "$actual_dylibs" == "$expected_dylibs" ]] \
  || fail "unexpected llama.cpp dylib inventory"
codesign --verify --strict --verbose=2 "$HELPER" || fail "helper signature is invalid"
codesign --verify --deep --strict --verbose=2 "$APP" || fail "app signature is invalid"
codesign -d --entitlements :- "$APP" >"$ENTITLEMENTS" 2>/dev/null \
  || fail "cannot read app entitlements"
plutil -lint "$ENTITLEMENTS" >/dev/null || fail "signed app entitlements are invalid"
REQUIRED_ENTITLEMENTS=(
  com.apple.security.app-sandbox
  com.apple.security.device.microphone
  com.apple.security.device.audio-input
  com.apple.security.network.client
  com.apple.security.network.server
  com.apple.security.files.user-selected.read-only
)
for key in "${REQUIRED_ENTITLEMENTS[@]}"; do
  [[ "$(plist_value "$ENTITLEMENTS" "$key" || true)" == "true" ]] \
    || fail "signed app entitlement $key is missing"
done
ENTITLEMENT_KEY_COUNT="$(grep -o '<key>' "$ENTITLEMENTS" | wc -l | tr -d ' ')"
[[ "$ENTITLEMENT_KEY_COUNT" == "${#REQUIRED_ENTITLEMENTS[@]}" ]] \
  || fail "signed app contains an unreviewed entitlement"

APP_SIGNATURE="$(codesign -dv --verbose=4 "$APP" 2>&1)"
HELPER_SIGNATURE="$(codesign -dv --verbose=4 "$HELPER" 2>&1)"
if [[ "$IDENTITY" == "-" ]]; then
  [[ "$APP_SIGNATURE" == *"Signature=adhoc"* ]] || fail "dry-run app is not ad-hoc signed"
else
  [[ "$APP_SIGNATURE" == *"Authority=Developer ID Application:"* ]] \
    || fail "app is not signed with Developer ID Application"
  [[ "$HELPER_SIGNATURE" == *"Authority=Developer ID Application:"* ]] \
    || fail "helper is not signed with Developer ID Application"
  [[ "$APP_SIGNATURE" == *"runtime"* && "$HELPER_SIGNATURE" == *"runtime"* ]] \
    || fail "hardened runtime is not enabled on app and helper"
  APP_TEAM="$(awk -F= '/^TeamIdentifier=/ {print $2; exit}' <<<"$APP_SIGNATURE")"
  HELPER_TEAM="$(awk -F= '/^TeamIdentifier=/ {print $2; exit}' <<<"$HELPER_SIGNATURE")"
  [[ "$APP_TEAM" =~ ^[A-Z0-9]{10}$ && "$HELPER_TEAM" == "$APP_TEAM" ]] \
    || fail "app and helper signing teams do not match"
fi

echo "Release app audit: PASS"
echo "App: $APP"
echo "Architectures: arm64"

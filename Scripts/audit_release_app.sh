#!/bin/bash
set -euo pipefail

fail() {
  echo "Release app audit failed: $*" >&2
  exit 1
}

plist_value() {
  /usr/libexec/PlistBuddy -c "Print :$2" "$1" 2>/dev/null
}

binary_contains() {
  local match_mode="$1"
  local pattern="$2"
  local binary="$3"
  local scan_status

  case "$match_mode" in
    fixed)
      if LC_ALL=C /usr/bin/grep -a -F -q -- "$pattern" "$binary"; then
        return 0
      else
        scan_status=$?
      fi
      ;;
    extended)
      if LC_ALL=C /usr/bin/grep -a -E -q -- "$pattern" "$binary"; then
        return 0
      else
        scan_status=$?
      fi
      ;;
    *)
      fail "unknown binary scan mode"
      ;;
  esac

  [[ "$scan_status" == "1" ]] && return 1
  fail "could not scan Mach-O for private build paths: $(basename "$binary")"
}

version_is_at_most() {
  /usr/bin/awk -v actual="$1" -v maximum="$2" '
    BEGIN {
      split(actual, a, ".")
      split(maximum, b, ".")
      for (i = 1; i <= 4; i += 1) {
        left = a[i] + 0
        right = b[i] + 0
        if (left < right) exit 0
        if (left > right) exit 1
      }
      exit 0
    }
  '
}

audit_macho_platform() {
  local binary="$1"
  local metadata
  local minos
  local platform

  metadata="$(
    otool -l "$binary" | awk '
      $1 == "cmd" && $2 == "LC_BUILD_VERSION" {
        count += 1
        reading = 1
        next
      }
      reading && $1 == "platform" { platform = $2; next }
      reading && $1 == "minos" { minos = $2; reading = 0; next }
      END {
        if (count == 1 && platform != "" && minos != "") {
          print platform, minos
        } else {
          exit 1
        }
      }
    '
  )" || fail "Mach-O has no unambiguous LC_BUILD_VERSION: $(basename "$binary")"
  read -r platform minos <<<"$metadata"
  [[ "$platform" == "MACOS" || "$platform" == "1" ]] \
    || fail "Mach-O targets a platform other than macOS: $(basename "$binary")"
  version_is_at_most "$minos" "15.0" \
    || fail "Mach-O requires macOS $minos, above the supported 15.0 minimum: $(basename "$binary")"
}

audit_macho_dependencies() {
  local binary="$1"
  local dependency
  local has_local_rpath=0
  local relative
  local rpath

  if binary_contains fixed "$REPOSITORY_ROOT/" "$binary" \
    || binary_contains extended \
      '/Users/[^/]+/([^/[:cntrl:]]+/)*(Live_Church_Translation|LiveChurchTranslation)/' \
      "$binary"; then
    fail "Mach-O contains an absolute project build path: $(basename "$binary")"
  fi

  while IFS= read -r rpath; do
    case "$rpath" in
      @loader_path | @executable_path)
        has_local_rpath=1
        ;;
      *)
        fail "Mach-O contains an external runtime search path: $rpath"
        ;;
    esac
  done < <(
    otool -l "$binary" \
      | awk '$1 == "cmd" && $2 == "LC_RPATH" { wanted = 1; next }
        wanted && $1 == "path" { print $2; wanted = 0 }'
  )

  while IFS= read -r dependency; do
    case "$dependency" in
      /System/Library/* | /usr/lib/*)
        ;;
      @rpath/*)
        relative="${dependency#@rpath/}"
        [[ "$has_local_rpath" == "1" \
          && -n "$relative" && "$relative" != */* \
          && -f "$CONTENTS/MacOS/$relative" \
          && ! -L "$CONTENTS/MacOS/$relative" ]] \
          || fail "Mach-O dependency is not bundled beside its executable: $dependency"
        ;;
      @loader_path/*)
        relative="${dependency#@loader_path/}"
        [[ -n "$relative" && "$relative" != */* \
          && -f "$(dirname "$binary")/$relative" \
          && ! -L "$(dirname "$binary")/$relative" ]] \
          || fail "Mach-O loader dependency is missing: $dependency"
        ;;
      *)
        fail "Mach-O contains an external runtime dependency: $dependency"
        ;;
    esac
  done < <(
    otool -L "$binary" \
      | tail -n +2 \
      | sed -E 's/^[[:space:]]*//; s/[[:space:]]+\(compatibility.*$//'
  )
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
ZH_HANS_INFO="$CONTENTS/Resources/zh-Hans.lproj/InfoPlist.strings"
ZH_HANT_INFO="$CONTENTS/Resources/zh-Hant.lproj/InfoPlist.strings"
ZH_HANT_LOCALIZABLE="$CONTENTS/Resources/zh-Hant.lproj/Localizable.strings"
ENTITLEMENTS="$(mktemp "${TMPDIR:-/tmp}/church-release-entitlements.XXXXXX")"
trap 'rm -f "$ENTITLEMENTS"' EXIT

[[ -x "$MAIN" && ! -L "$MAIN" ]] || fail "main executable is missing"
[[ -x "$HELPER" && ! -L "$HELPER" ]] || fail "llama-server is missing"
[[ ! -e "$CONTENTS/Helpers/llama-server" ]] || fail "legacy helper path is present"
[[ -f "$INFO" && -f "$PRIVACY" ]] || fail "required bundle metadata is missing"
[[ -f "$ZH_HANS_INFO" && ! -L "$ZH_HANS_INFO" ]] \
  || fail "Simplified Chinese InfoPlist localization is missing or unsafe"
[[ -f "$ZH_HANT_INFO" && ! -L "$ZH_HANT_INFO" ]] \
  || fail "Traditional Chinese InfoPlist localization is missing or unsafe"
[[ -f "$ZH_HANT_LOCALIZABLE" && ! -L "$ZH_HANT_LOCALIZABLE" ]] \
  || fail "Traditional Chinese interface localization is missing or unsafe"
plutil -lint "$INFO" "$PRIVACY" "$ZH_HANS_INFO" "$ZH_HANT_INFO" \
  "$ZH_HANT_LOCALIZABLE" >/dev/null || fail "bundle metadata or localization is invalid"
[[ "$(plist_value "$ZH_HANT_INFO" "NSMicrophoneUsageDescription" || true)" \
  == "用於實時語音識別、翻譯和錄音。" ]] \
  || fail "Traditional Chinese microphone usage description is invalid"
[[ "$(plist_value "$ZH_HANT_INFO" "NSLocalNetworkUsageDescription" || true)" \
  == "用於向同一網絡的聽眾顯示實時字幕。" ]] \
  || fail "Traditional Chinese local-network usage description is invalid"
rg -Fq '"显示" = "顯示";' "$ZH_HANT_LOCALIZABLE" \
  || fail "Traditional Chinese interface localization is incomplete"
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
audit_macho_dependencies "$MAIN"
audit_macho_dependencies "$HELPER"
audit_macho_platform "$MAIN"
audit_macho_platform "$HELPER"
for library in "$CONTENTS"/MacOS/*.dylib; do
  audit_macho_dependencies "$library"
  audit_macho_platform "$library"
done
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
echo "Deployment compatibility: macOS 15.0 or earlier"

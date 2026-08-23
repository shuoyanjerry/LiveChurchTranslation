#!/bin/bash
set -euo pipefail

fail() {
  echo "Release evidence generation failed: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP="${1:-$REPOSITORY_ROOT/dist/Quiet Liturgy Reader.app}"
DMG="${2:-$REPOSITORY_ROOT/dist/Quiet Liturgy Reader.dmg}"
RELEASE_MODE="${3:-dry-run}"
EVIDENCE_DIR="$REPOSITORY_ROOT/dist/release-evidence"
SOURCE_MANIFEST="$SCRIPT_DIR/release_model_sources.tsv"
MODEL_ROOT="$APP/Contents/Resources/Models"
MODEL_MANIFEST="$EVIDENCE_DIR/MODEL-MANIFEST.tsv"
APP_MANIFEST="$EVIDENCE_DIR/APP-CONTENTS.sha256"
RUNTIME_MANIFEST="$EVIDENCE_DIR/RUNTIME-MANIFEST.sha256"
LICENSE_MANIFEST="$EVIDENCE_DIR/LICENSE-MANIFEST.sha256"
REPORT="$EVIDENCE_DIR/RELEASE-REPORT.md"
CHECKSUMS="$EVIDENCE_DIR/SHA256SUMS"

[[ "$RELEASE_MODE" == "dry-run" || "$RELEASE_MODE" == "developer-id-notarized" ]] \
  || fail "release mode must be dry-run or developer-id-notarized"
[[ -d "$APP" && -f "$DMG" ]] || fail "app and DMG must exist before evidence generation"
"$SCRIPT_DIR/check_release_models.sh" "$MODEL_ROOT"
mkdir -p "$EVIDENCE_DIR"
rm -f \
  "$MODEL_MANIFEST" "$APP_MANIFEST" "$RUNTIME_MANIFEST" "$LICENSE_MANIFEST" \
  "$REPORT" "$CHECKSUMS"
if [[ "$RELEASE_MODE" == "dry-run" ]]; then
  rm -f "$EVIDENCE_DIR"/notary-*.json
fi

printf 'model_id\trelative_path\tbytes\tsha256\timmutable_url\n' >"$MODEL_MANIFEST"
while IFS=$'\t' read -r bundled_path remote_url; do
  [[ -n "$bundled_path" && "${bundled_path:0:1}" != "#" ]] || continue
  model_id="${bundled_path%%/*}"
  relative_path="${bundled_path#*/}"
  file="$MODEL_ROOT/$bundled_path"
  actual_bytes="$(wc -c <"$file" | tr -d ' ')"
  actual_sha="$(shasum -a 256 "$file" | awk '{print $1}')"
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$model_id" "$relative_path" "$actual_bytes" "$actual_sha" "$remote_url" \
    >>"$MODEL_MANIFEST"
done <"$SOURCE_MANIFEST"

while IFS= read -r file; do
  relative="${file#"$APP/"}"
  printf '%s  %s\n' "$(shasum -a 256 "$file" | awk '{print $1}')" "$relative"
done < <(find "$APP/Contents" -type f | LC_ALL=C sort) >"$APP_MANIFEST"
ditto "$REPOSITORY_ROOT/Packaging/LlamaRuntime.sha256" "$RUNTIME_MANIFEST"
ditto "$REPOSITORY_ROOT/Packaging/LicenseFiles.sha256" "$LICENSE_MANIFEST"

INFO="$APP/Contents/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO")"
COMMIT="$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)"
DMG_BYTES="$(stat -f '%z' "$DMG")"
[[ "$DMG_BYTES" -lt 2147483648 ]] \
  || fail "final DMG must be smaller than GitHub's 2 GiB per-asset limit"
DMG_SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"
APP_BYTES="$(find "$APP" -type f -exec stat -f '%z' {} + | awk '{total += $1} END {print total + 0}')"
SWIFT_VERSION="$(swift --version | head -n 1)"
if XCODE_VERSION="$(xcodebuild -version 2>/dev/null | paste -sd ' ' -)"; then
  :
else
  XCODE_VERSION="full Xcode unavailable"
fi
SIGNATURE="$(codesign -dv --verbose=4 "$APP" 2>&1)"
TEAM="$(awk -F= '/^TeamIdentifier=/ {print $2; exit}' <<<"$SIGNATURE")"
[[ -n "$TEAM" ]] || TEAM="ad-hoc"

APP_NOTARY_ID="not performed"
APP_NOTARY_STATUS="dry-run"
DMG_NOTARY_ID="not performed"
DMG_NOTARY_STATUS="dry-run"
if [[ "$RELEASE_MODE" == "developer-id-notarized" ]]; then
  APP_NOTARY_JSON="$EVIDENCE_DIR/notary-app.json"
  DMG_NOTARY_JSON="$EVIDENCE_DIR/notary-dmg.json"
  [[ -f "$APP_NOTARY_JSON" && -f "$DMG_NOTARY_JSON" ]] \
    || fail "notarization evidence is missing"
  APP_NOTARY_ID="$(plutil -extract id raw -o - "$APP_NOTARY_JSON")"
  APP_NOTARY_STATUS="$(plutil -extract status raw -o - "$APP_NOTARY_JSON")"
  DMG_NOTARY_ID="$(plutil -extract id raw -o - "$DMG_NOTARY_JSON")"
  DMG_NOTARY_STATUS="$(plutil -extract status raw -o - "$DMG_NOTARY_JSON")"
  [[ "$APP_NOTARY_STATUS" == "Accepted" && "$DMG_NOTARY_STATUS" == "Accepted" ]] \
    || fail "notarization evidence is not Accepted"
fi

{
  printf '# Release candidate evidence\n\n'
  printf '> Packaging evidence only. This report does not establish production readiness, '
  printf 'linguistic quality, theological correctness, long-session reliability, or clean-Mac acceptance.\n\n'
  printf -- '- Version/build: `%s (%s)`\n' "$VERSION" "$BUILD"
  printf -- '- Git commit: `%s`\n' "$COMMIT"
  printf -- '- Generated UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Mode: `%s`\n' "$RELEASE_MODE"
  printf -- '- Architecture: `arm64`\n'
  printf -- '- Swift: `%s`\n' "$SWIFT_VERSION"
  printf -- '- Xcode: `%s`\n' "$XCODE_VERSION"
  printf -- '- Signing team: `%s`\n' "$TEAM"
  printf -- '- App bytes: `%s`\n' "$APP_BYTES"
  printf -- '- DMG bytes: `%s`\n' "$DMG_BYTES"
  printf -- '- DMG SHA-256: `%s`\n' "$DMG_SHA"
  printf -- '- App notarization: `%s` (`%s`)\n' "$APP_NOTARY_STATUS" "$APP_NOTARY_ID"
  printf -- '- DMG notarization: `%s` (`%s`)\n\n' "$DMG_NOTARY_STATUS" "$DMG_NOTARY_ID"
  printf 'The candidate contains seven revision-pinned model artifacts totaling '
  printf '2,120,095,795 bytes. Exact paths, sizes, hashes, and immutable source URLs are in '
  printf '`MODEL-MANIFEST.tsv`. Runtime and full app-content hashes are recorded separately.\n\n'
  printf 'Tracked third-party license files are sealed under `Resources/Licenses`; their '
  printf 'digests are recorded in `LICENSE-MANIFEST.sha256`.\n\n'
  printf 'Promotion remains blocked until every release gate in `Docs/Testing.md` has current, '
  printf 'independently reviewable evidence. Tag automation creates a draft prerelease only.\n'
} >"$REPORT"

{
  printf '%s  %s\n' "$DMG_SHA" "$(basename "$DMG")"
  while IFS= read -r file; do
    [[ "$file" != "$CHECKSUMS" ]] || continue
    printf '%s  release-evidence/%s\n' \
      "$(shasum -a 256 "$file" | awk '{print $1}')" "$(basename "$file")"
  done < <(find "$EVIDENCE_DIR" -maxdepth 1 -type f | LC_ALL=C sort)
} >"$CHECKSUMS"

echo "Release evidence created: $EVIDENCE_DIR"

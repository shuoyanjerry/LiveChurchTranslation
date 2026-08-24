#!/bin/bash
set -euo pipefail
umask 077

fail() {
  echo "Release evidence generation failed: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP="${1:-$REPOSITORY_ROOT/dist/Live Church Translation.app}"
DMG="${2:-$REPOSITORY_ROOT/dist/Live Church Translation.dmg}"
RELEASE_MODE="${3:-dry-run}"
EVIDENCE_DIR="$REPOSITORY_ROOT/dist/Live Church Translation.release-evidence"
EVIDENCE_LABEL="$(basename "$EVIDENCE_DIR")"
SOURCE_MANIFEST="$SCRIPT_DIR/release_model_sources.tsv"
NOTARY_VALIDATOR="$SCRIPT_DIR/validate_notary_evidence.py"
MODEL_ROOT="$APP/Contents/Resources/Models"
MODEL_MANIFEST="$EVIDENCE_DIR/MODEL-MANIFEST.tsv"
APP_MANIFEST="$EVIDENCE_DIR/APP-CONTENTS.sha256"
RUNTIME_MANIFEST="$EVIDENCE_DIR/RUNTIME-MANIFEST.sha256"
LICENSE_MANIFEST="$EVIDENCE_DIR/LICENSE-MANIFEST.sha256"
REPORT="$EVIDENCE_DIR/RELEASE-REPORT.md"
CHECKSUMS="$EVIDENCE_DIR/SHA256SUMS"

[[ "$RELEASE_MODE" == "dry-run" || "$RELEASE_MODE" == "developer-id-notarized" ]] \
  || fail "release mode must be dry-run or developer-id-notarized"
[[ -f "$NOTARY_VALIDATOR" && ! -L "$NOTARY_VALIDATOR" && -x "$NOTARY_VALIDATOR" ]] \
  || fail "notarization evidence validator is missing or unsafe"
[[ "$(basename "$APP")" == "Live Church Translation.app" ]] \
  || fail "app artifact must be named Live Church Translation.app"
[[ "$(basename "$DMG")" == "Live Church Translation.dmg" ]] \
  || fail "DMG artifact must be named Live Church Translation.dmg"
COMMIT="$(git -C "$REPOSITORY_ROOT" rev-parse HEAD)"
if [[ -z "$(git -C "$REPOSITORY_ROOT" status --porcelain=v1 --untracked-files=normal)" ]]; then
  SOURCE_STATE="clean"
else
  SOURCE_STATE="dirty"
fi
if [[ "$RELEASE_MODE" == "developer-id-notarized" && "$SOURCE_STATE" != "clean" ]]; then
  fail "a formal release must be built from a clean Git worktree"
fi
[[ -d "$APP" && ! -L "$APP" && -f "$DMG" && ! -L "$DMG" ]] \
  || fail "app and DMG must exist as ordinary artifacts before evidence generation"
"$SCRIPT_DIR/check_release_models.sh" "$MODEL_ROOT"
mkdir -p "$EVIDENCE_DIR"
[[ -d "$EVIDENCE_DIR" && ! -L "$EVIDENCE_DIR" ]] \
  || fail "release evidence directory is unsafe"
chmod 0700 "$EVIDENCE_DIR"
rm -f \
  "$MODEL_MANIFEST" "$APP_MANIFEST" "$RUNTIME_MANIFEST" "$LICENSE_MANIFEST" \
  "$REPORT" "$CHECKSUMS"
if [[ "$RELEASE_MODE" == "dry-run" ]]; then
  rm -f "$EVIDENCE_DIR"/notary-*.json "$EVIDENCE_DIR"/notary-*-submitted.sha256
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
if [[ -z "$TEAM" || "$TEAM" == "not set" ]]; then
  TEAM="ad-hoc"
fi

APP_NOTARY_ID="not performed"
APP_NOTARY_STATUS="dry-run"
DMG_NOTARY_ID="not performed"
DMG_NOTARY_STATUS="dry-run"
APP_SUBMITTED_SHA="not performed"
DMG_SUBMITTED_SHA="not performed"
if [[ "$RELEASE_MODE" == "developer-id-notarized" ]]; then
  APP_NOTARY_JSON="$EVIDENCE_DIR/notary-app.json"
  APP_NOTARY_LOG="$EVIDENCE_DIR/notary-app-log.json"
  APP_SUBMITTED_DIGEST="$EVIDENCE_DIR/notary-app-submitted.sha256"
  DMG_NOTARY_JSON="$EVIDENCE_DIR/notary-dmg.json"
  DMG_NOTARY_LOG="$EVIDENCE_DIR/notary-dmg-log.json"
  DMG_SUBMITTED_DIGEST="$EVIDENCE_DIR/notary-dmg-submitted.sha256"
  [[ -f "$APP_NOTARY_JSON" && ! -L "$APP_NOTARY_JSON" \
    && -f "$APP_NOTARY_LOG" && ! -L "$APP_NOTARY_LOG" \
    && -f "$APP_SUBMITTED_DIGEST" && ! -L "$APP_SUBMITTED_DIGEST" \
    && -f "$DMG_NOTARY_JSON" && ! -L "$DMG_NOTARY_JSON" \
    && -f "$DMG_NOTARY_LOG" && ! -L "$DMG_NOTARY_LOG" \
    && -f "$DMG_SUBMITTED_DIGEST" && ! -L "$DMG_SUBMITTED_DIGEST" ]] \
    || fail "notarization evidence is missing"
  for notary_file in \
    "$APP_NOTARY_JSON" "$APP_NOTARY_LOG" "$APP_SUBMITTED_DIGEST" \
    "$DMG_NOTARY_JSON" "$DMG_NOTARY_LOG" "$DMG_SUBMITTED_DIGEST"; do
    [[ -s "$notary_file" ]] || fail "notarization evidence is empty: $(basename "$notary_file")"
    [[ "$(stat -f '%Lp' "$notary_file")" == "600" ]] \
      || fail "notarization evidence must use owner-only permissions: $(basename "$notary_file")"
  done
  APP_SUBMITTED_SHA="$(
    "$NOTARY_VALIDATOR" "$APP_NOTARY_JSON" "$APP_NOTARY_LOG" \
      --expected-sha-file "$APP_SUBMITTED_DIGEST"
  )" || fail "app notarization evidence is not internally bound"
  DMG_SUBMITTED_SHA="$(
    "$NOTARY_VALIDATOR" "$DMG_NOTARY_JSON" "$DMG_NOTARY_LOG" \
      --expected-sha-file "$DMG_SUBMITTED_DIGEST"
  )" || fail "DMG notarization evidence is not internally bound"
  APP_NOTARY_ID="$(plutil -extract id raw -o - "$APP_NOTARY_JSON")"
  APP_NOTARY_STATUS="$(plutil -extract status raw -o - "$APP_NOTARY_JSON")"
  DMG_NOTARY_ID="$(plutil -extract id raw -o - "$DMG_NOTARY_JSON")"
  DMG_NOTARY_STATUS="$(plutil -extract status raw -o - "$DMG_NOTARY_JSON")"
  [[ "$APP_NOTARY_STATUS" == "Accepted" && "$DMG_NOTARY_STATUS" == "Accepted" ]] \
    || fail "notarization evidence is not Accepted"
  xcrun stapler validate "$APP" >/dev/null \
    || fail "the app notarization ticket is not valid"
  xcrun stapler validate "$DMG" >/dev/null \
    || fail "the DMG notarization ticket is not valid"
  hdiutil verify "$DMG" >/dev/null || fail "the final stapled DMG is invalid"
  spctl --assess --type execute --verbose=4 "$APP" >/dev/null \
    || fail "Gatekeeper rejected the app"
  spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG" \
    >/dev/null || fail "Gatekeeper rejected the DMG"
fi

{
  printf '# Release candidate evidence\n\n'
  printf '> Packaging evidence only. This report does not establish production readiness, '
  printf 'linguistic quality, theological correctness, long-session reliability, or clean-Mac acceptance.\n\n'
  printf -- '- Version/build: `%s (%s)`\n' "$VERSION" "$BUILD"
  printf -- '- Git commit: `%s`\n' "$COMMIT"
  printf -- '- Git source state: `%s`\n' "$SOURCE_STATE"
  printf -- '- Generated UTC: `%s`\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  printf -- '- Mode: `%s`\n' "$RELEASE_MODE"
  printf -- '- Architecture: `arm64`\n'
  printf -- '- Swift: `%s`\n' "$SWIFT_VERSION"
  printf -- '- Xcode: `%s`\n' "$XCODE_VERSION"
  printf -- '- Signing team: `%s`\n' "$TEAM"
  printf -- '- App bytes: `%s`\n' "$APP_BYTES"
  printf -- '- DMG bytes: `%s`\n' "$DMG_BYTES"
  printf -- '- DMG SHA-256: `%s`\n' "$DMG_SHA"
  if [[ "$RELEASE_MODE" == "developer-id-notarized" ]]; then
    printf -- '- App notarization: `%s` (`%s`)\n' "$APP_NOTARY_STATUS" "$APP_NOTARY_ID"
    printf -- '- App submission JSON: `%s/notary-app.json`\n' "$EVIDENCE_LABEL"
    printf -- '- App notarization log: `%s/notary-app-log.json`\n' "$EVIDENCE_LABEL"
    printf -- '- App submitted ZIP SHA-256: `%s`\n' "$APP_SUBMITTED_SHA"
    printf -- '- App submitted SHA seal: `%s/notary-app-submitted.sha256`\n' \
      "$EVIDENCE_LABEL"
    printf -- '- DMG notarization: `%s` (`%s`)\n' "$DMG_NOTARY_STATUS" "$DMG_NOTARY_ID"
    printf -- '- DMG submission JSON: `%s/notary-dmg.json`\n' "$EVIDENCE_LABEL"
    printf -- '- DMG notarization log: `%s/notary-dmg-log.json`\n' "$EVIDENCE_LABEL"
    printf -- '- Submitted DMG SHA-256: `%s`\n' "$DMG_SUBMITTED_SHA"
    printf -- '- Submitted DMG SHA seal: `%s/notary-dmg-submitted.sha256`\n\n' \
      "$EVIDENCE_LABEL"
  else
    printf -- '- App notarization: `not performed` (`dry-run`)\n'
    printf -- '- DMG notarization: `not performed` (`dry-run`)\n\n'
  fi
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
    printf '%s  %s/%s\n' \
      "$(shasum -a 256 "$file" | awk '{print $1}')" \
      "$EVIDENCE_LABEL" "$(basename "$file")"
  done < <(find "$EVIDENCE_DIR" -maxdepth 1 -type f | LC_ALL=C sort)
} >"$CHECKSUMS"

echo "Release evidence created: $EVIDENCE_DIR"

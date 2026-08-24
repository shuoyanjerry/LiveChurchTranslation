#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP="$REPOSITORY_ROOT/dist/Live Church Translation.app"
DMG="$REPOSITORY_ROOT/dist/Live Church Translation.dmg"
EVIDENCE_DIR="$REPOSITORY_ROOT/dist/Live Church Translation.release-evidence"

fail() {
  echo "Release notarization failed: $*" >&2
  exit 1
}

[[ -z "$(git -C "$REPOSITORY_ROOT" status --porcelain=v1 --untracked-files=normal)" ]] \
  || fail "a formal release must start from a clean Git worktree"
: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to a Developer ID identity}"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
else
  : "${APPLE_NOTARY_KEY_PATH:?Set APPLE_NOTARY_KEY_PATH or NOTARY_PROFILE}"
  : "${APPLE_NOTARY_KEY_ID:?Set APPLE_NOTARY_KEY_ID or NOTARY_PROFILE}"
  : "${APPLE_NOTARY_ISSUER_ID:?Set APPLE_NOTARY_ISSUER_ID or NOTARY_PROFILE}"
  [[ -f "$APPLE_NOTARY_KEY_PATH" && ! -L "$APPLE_NOTARY_KEY_PATH" ]] \
    || fail "APPLE_NOTARY_KEY_PATH is missing or unsafe"
  NOTARY_ARGS=(
    --key "$APPLE_NOTARY_KEY_PATH"
    --key-id "$APPLE_NOTARY_KEY_ID"
    --issuer "$APPLE_NOTARY_ISSUER_ID"
  )
fi

submit_and_require_acceptance() {
  local artifact="$1"
  local output="$2"
  local log_output="$3"
  local submission_id
  local status
  if ! xcrun notarytool submit "$artifact" "${NOTARY_ARGS[@]}" \
    --wait --output-format json >"$output"; then
    fail "notarytool could not submit $(basename "$artifact")"
  fi
  submission_id="$(plutil -extract id raw -o - "$output" 2>/dev/null || true)"
  status="$(plutil -extract status raw -o - "$output" 2>/dev/null || true)"
  [[ -n "$submission_id" ]] || fail "notarytool returned no submission ID"
  if [[ "$status" != "Accepted" ]]; then
    xcrun notarytool log "$submission_id" "${NOTARY_ARGS[@]}" \
      --output-format json >"$log_output" || true
    fail "notary submission $submission_id returned status ${status:-unknown}"
  fi
  echo "Accepted notarization submission: $submission_id"
}

"$SCRIPT_DIR/package_release.sh"
ZIP="$REPOSITORY_ROOT/dist/Live Church Translation.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
mkdir -p "$EVIDENCE_DIR"
rm -f \
  "$EVIDENCE_DIR/notary-app.json" "$EVIDENCE_DIR/notary-app-log.json" \
  "$EVIDENCE_DIR/notary-dmg.json" "$EVIDENCE_DIR/notary-dmg-log.json"
submit_and_require_acceptance \
  "$ZIP" "$EVIDENCE_DIR/notary-app.json" "$EVIDENCE_DIR/notary-app-log.json"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
rm -f "$ZIP"
"$SCRIPT_DIR/check_release_disk_space.sh" 3221225472 "before notarized DMG creation"
"$SCRIPT_DIR/create_dmg.sh"
submit_and_require_acceptance \
  "$DMG" "$EVIDENCE_DIR/notary-dmg.json" "$EVIDENCE_DIR/notary-dmg-log.json"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type execute --verbose=4 "$APP"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG"
"$SCRIPT_DIR/generate_release_evidence.sh" "$APP" "$DMG" developer-id-notarized

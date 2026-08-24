#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP="$REPOSITORY_ROOT/dist/Live Church Translation.app"
DMG="$REPOSITORY_ROOT/dist/Live Church Translation.dmg"
EVIDENCE_DIR="$REPOSITORY_ROOT/dist/Live Church Translation.release-evidence"
NOTARY_VALIDATOR="$SCRIPT_DIR/validate_notary_evidence.py"

fail() {
  echo "Release notarization failed: $*" >&2
  exit 1
}

[[ -f "$NOTARY_VALIDATOR" && ! -L "$NOTARY_VALIDATOR" && -x "$NOTARY_VALIDATOR" ]] \
  || fail "notarization evidence validator is missing or unsafe"
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

TEMPORARY_EVIDENCE=()
cleanup_temporary_evidence() {
  local temporary
  for temporary in "${TEMPORARY_EVIDENCE[@]}"; do
    [[ -z "$temporary" ]] || rm -f "$temporary"
  done
}
trap cleanup_temporary_evidence EXIT

submit_and_require_acceptance() {
  local artifact="$1"
  local output="$2"
  local log_output="$3"
  local digest_output="$4"
  local artifact_sha
  local digest_tmp
  local output_tmp
  local log_tmp
  local submission_id
  local status
  local validated_sha

  [[ -f "$artifact" && ! -L "$artifact" ]] \
    || fail "notarization artifact is missing or unsafe: $(basename "$artifact")"
  output_tmp="$(mktemp "$EVIDENCE_DIR/.notary-submit.XXXXXX")" \
    || fail "could not create private notarization evidence"
  TEMPORARY_EVIDENCE+=("$output_tmp")
  log_tmp="$(mktemp "$EVIDENCE_DIR/.notary-log.XXXXXX")" \
    || fail "could not create private notarization log storage"
  TEMPORARY_EVIDENCE+=("$log_tmp")
  digest_tmp="$(mktemp "$EVIDENCE_DIR/.notary-digest.XXXXXX")" \
    || fail "could not create private submitted-artifact digest"
  TEMPORARY_EVIDENCE+=("$digest_tmp")
  chmod 0600 "$output_tmp" "$log_tmp" "$digest_tmp"
  artifact_sha="$(shasum -a 256 "$artifact" | awk '{print $1}')"
  [[ "$artifact_sha" =~ ^[0-9a-f]{64}$ ]] \
    || fail "could not seal the submitted artifact digest"
  printf '%s\n' "$artifact_sha" >"$digest_tmp"

  if ! xcrun notarytool submit "$artifact" "${NOTARY_ARGS[@]}" \
    --wait --output-format json >"$output_tmp"; then
    fail "notarytool could not submit $(basename "$artifact")"
  fi
  [[ -s "$output_tmp" ]] || fail "notarytool returned no submission evidence"
  submission_id="$(plutil -extract id raw -o - "$output_tmp" 2>/dev/null || true)"
  status="$(plutil -extract status raw -o - "$output_tmp" 2>/dev/null || true)"
  [[ -n "$submission_id" ]] || fail "notarytool returned no submission ID"

  xcrun notarytool log "$submission_id" "${NOTARY_ARGS[@]}" \
    --output-format json >"$log_tmp" \
    || fail "notary submission $submission_id has no downloadable log"
  [[ -s "$log_tmp" ]] || fail "notary submission $submission_id returned an empty log"
  validated_sha="$(
    "$NOTARY_VALIDATOR" "$output_tmp" "$log_tmp" \
      --artifact "$artifact" --expected-sha-file "$digest_tmp"
  )" || fail "notary submission $submission_id is not bound to its artifact"
  [[ "$validated_sha" == "$artifact_sha" ]] \
    || fail "notary submission $submission_id returned an unexpected artifact digest"
  [[ "$status" == "Accepted" ]] \
    || fail "notary submission $submission_id returned status ${status:-unknown}"

  mv -f "$output_tmp" "$output"
  mv -f "$log_tmp" "$log_output"
  mv -f "$digest_tmp" "$digest_output"
  echo "Accepted notarization submission: $submission_id"
}

"$SCRIPT_DIR/package_release.sh"
umask 077
ZIP="$REPOSITORY_ROOT/dist/Live Church Translation.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
mkdir -p "$EVIDENCE_DIR"
[[ -d "$EVIDENCE_DIR" && ! -L "$EVIDENCE_DIR" ]] \
  || fail "notarization evidence directory is unsafe"
chmod 0700 "$EVIDENCE_DIR"
rm -f \
  "$EVIDENCE_DIR/notary-app.json" "$EVIDENCE_DIR/notary-app-log.json" \
  "$EVIDENCE_DIR/notary-app-submitted.sha256" \
  "$EVIDENCE_DIR/notary-dmg.json" "$EVIDENCE_DIR/notary-dmg-log.json" \
  "$EVIDENCE_DIR/notary-dmg-submitted.sha256"
submit_and_require_acceptance \
  "$ZIP" "$EVIDENCE_DIR/notary-app.json" "$EVIDENCE_DIR/notary-app-log.json" \
  "$EVIDENCE_DIR/notary-app-submitted.sha256"
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
rm -f "$ZIP"
"$SCRIPT_DIR/check_release_disk_space.sh" 3221225472 "before notarized DMG creation"
"$SCRIPT_DIR/create_dmg.sh"
submit_and_require_acceptance \
  "$DMG" "$EVIDENCE_DIR/notary-dmg.json" "$EVIDENCE_DIR/notary-dmg-log.json" \
  "$EVIDENCE_DIR/notary-dmg-submitted.sha256"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
hdiutil verify "$DMG"
spctl --assess --type execute --verbose=4 "$APP"
spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG"
"$SCRIPT_DIR/generate_release_evidence.sh" "$APP" "$DMG" developer-id-notarized

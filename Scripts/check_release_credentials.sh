#!/bin/bash
set -euo pipefail

fail() {
  echo "Release credential check failed: $*" >&2
  exit 1
}

required=(
  DEVELOPER_ID_APPLICATION
  RELEASE_SIGNING_CERTIFICATE_BASE64
  RELEASE_SIGNING_CERTIFICATE_PASSWORD
  APPLE_NOTARY_KEY_BASE64
  APPLE_NOTARY_KEY_ID
  APPLE_NOTARY_ISSUER_ID
)
missing=()
for name in "${required[@]}"; do
  [[ -n "${!name:-}" ]] || missing+=("$name")
done
if [[ "${#missing[@]}" -gt 0 ]]; then
  fail "missing required secret environment variables: ${missing[*]}"
fi

[[ "$DEVELOPER_ID_APPLICATION" == *"Developer ID Application:"* \
  && "$DEVELOPER_ID_APPLICATION" != *$'\n'* ]] \
  || fail "DEVELOPER_ID_APPLICATION must be one single-line Developer ID Application identity"
[[ "$APPLE_NOTARY_KEY_ID" =~ ^[A-Z0-9]{10}$ ]] \
  || fail "APPLE_NOTARY_KEY_ID must contain ten uppercase letters or digits"
[[ "$APPLE_NOTARY_ISSUER_ID" =~ ^[0-9a-fA-F-]{36}$ ]] \
  || fail "APPLE_NOTARY_ISSUER_ID must be a 36-character issuer UUID"

echo "Release credential names and formats: PASS"

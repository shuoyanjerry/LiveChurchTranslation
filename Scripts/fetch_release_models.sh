#!/bin/bash
set -euo pipefail

fail() {
  echo "Release model fetch failed: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SOURCE_MANIFEST="$SCRIPT_DIR/release_model_sources.tsv"
SHA_MANIFEST="$REPOSITORY_ROOT/Packaging/ProductionModels.sha256"
SIZE_MANIFEST="$REPOSITORY_ROOT/Packaging/ProductionModels.sizes"
OUTPUT_ROOT="${1:-$REPOSITORY_ROOT/.artifacts/release-models}"

[[ -f "$SOURCE_MANIFEST" && ! -L "$SOURCE_MANIFEST" ]] \
  || fail "tracked model source manifest is missing"
[[ -f "$SHA_MANIFEST" && -f "$SIZE_MANIFEST" ]] \
  || fail "tracked model integrity manifests are missing"
[[ -n "$OUTPUT_ROOT" && "$OUTPUT_ROOT" != "/" ]] || fail "unsafe output root"
if [[ -e "$OUTPUT_ROOT" || -L "$OUTPUT_ROOT" ]]; then
  [[ -d "$OUTPUT_ROOT" && ! -L "$OUTPUT_ROOT" ]] || fail "output root is not a safe directory"
else
  mkdir -p "$OUTPUT_ROOT"
fi

verify_file() {
  local file="$1"
  local expected_bytes="$2"
  local expected_sha="$3"
  [[ -f "$file" && ! -L "$file" ]] || return 1
  [[ "$(wc -c <"$file" | tr -d ' ')" == "$expected_bytes" ]] || return 1
  [[ "$(shasum -a 256 "$file" | awk '{print $1}')" == "$expected_sha" ]]
}

while IFS=$'\t' read -r relative_path remote_url; do
  [[ -n "$relative_path" && "${relative_path:0:1}" != "#" ]] || continue
  [[ "$relative_path" != /* && "$relative_path" != *".."* \
    && "$relative_path" != *"\\"* ]] || fail "unsafe model path: $relative_path"
  expected_bytes="$(awk -v path="$relative_path" '$2 == path {print $1}' "$SIZE_MANIFEST")"
  expected_sha="$(awk -v path="$relative_path" '$2 == path {print $1}' "$SHA_MANIFEST")"
  [[ "$expected_bytes" =~ ^[1-9][0-9]*$ ]] || fail "invalid byte count for $relative_path"
  [[ "$expected_sha" =~ ^[0-9a-f]{64}$ ]] || fail "invalid SHA-256 for $relative_path"
  [[ "$remote_url" == https://* ]] || fail "model URL is not HTTPS: $remote_url"

  destination="$OUTPUT_ROOT/$relative_path"
  if verify_file "$destination" "$expected_bytes" "$expected_sha"; then
    echo "Verified cached model artifact: $relative_path"
    continue
  fi

  mkdir -p "$(dirname "$destination")"
  partial="$destination.part"
  rm -f "$destination" "$partial"
  echo "Downloading pinned model artifact: $relative_path"
  curl --fail --location --retry 3 --retry-all-errors \
    --proto '=https' --tlsv1.2 --connect-timeout 30 \
    --output "$partial" "$remote_url"
  verify_file "$partial" "$expected_bytes" "$expected_sha" \
    || fail "downloaded artifact failed verification: $relative_path"
  chmod 0644 "$partial"
  mv "$partial" "$destination"
done <"$SOURCE_MANIFEST"

"$SCRIPT_DIR/check_release_models.sh" "$OUTPUT_ROOT"

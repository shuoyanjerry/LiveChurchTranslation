#!/bin/bash
set -euo pipefail

fail() {
  echo "Bundled model check failed: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MODELS_ROOT="${1:-}"
SHA_MANIFEST="$REPOSITORY_ROOT/Packaging/ProductionModels.sha256"
SIZE_MANIFEST="$REPOSITORY_ROOT/Packaging/ProductionModels.sizes"

[[ -n "$MODELS_ROOT" ]] || fail "usage: $0 /path/to/Models"
[[ -d "$MODELS_ROOT" && ! -L "$MODELS_ROOT" ]] || fail "model root is missing or unsafe"
[[ -f "$SHA_MANIFEST" && -f "$SIZE_MANIFEST" ]] || fail "model manifests are missing"
[[ "$(wc -l <"$SHA_MANIFEST" | tr -d ' ')" == "7" ]] || fail "SHA manifest must list 7 files"
[[ "$(wc -l <"$SIZE_MANIFEST" | tr -d ' ')" == "7" ]] || fail "size manifest must list 7 files"
[[ -z "$(find "$MODELS_ROOT" -type l -print -quit)" ]] || fail "model tree contains a symlink"
[[ "$(find "$MODELS_ROOT" -type f | wc -l | tr -d ' ')" == "7" ]] \
  || fail "model tree must contain exactly 7 files"

while read -r expected relative; do
  file="$MODELS_ROOT/$relative"
  [[ -f "$file" && ! -L "$file" ]] || fail "missing model file: $relative"
  actual="$(stat -f '%z' "$file")"
  [[ "$actual" == "$expected" ]] \
    || fail "wrong byte count for $relative: expected $expected, got $actual"
done <"$SIZE_MANIFEST"

(cd "$MODELS_ROOT" && shasum -a 256 -c "$SHA_MANIFEST" >/dev/null) \
  || fail "model SHA-256 verification failed"

echo "Bundled model check: PASS"

#!/bin/bash
set -euo pipefail

fail() {
  echo "Bundled license check failed: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LICENSE_ROOT="${1:-}"
MANIFEST="$REPOSITORY_ROOT/Packaging/LicenseFiles.sha256"

[[ -n "$LICENSE_ROOT" ]] || fail "usage: $0 /path/to/Licenses"
[[ -d "$LICENSE_ROOT" && ! -L "$LICENSE_ROOT" ]] \
  || fail "license directory is missing or unsafe"
[[ -f "$MANIFEST" && ! -L "$MANIFEST" ]] || fail "license manifest is missing"
[[ -z "$(find "$LICENSE_ROOT" -type l -print -quit)" ]] \
  || fail "license directory contains a symbolic link"
[[ "$(find "$LICENSE_ROOT" -maxdepth 1 -type f | wc -l | tr -d ' ')" == "8" ]] \
  || fail "license directory must contain exactly 8 files"

while read -r expected name; do
  [[ "$name" != */* && "$name" != .* ]] || fail "unsafe license filename: $name"
  file="$LICENSE_ROOT/$name"
  [[ -s "$file" && ! -L "$file" ]] || fail "missing license file: $name"
  [[ "$(shasum -a 256 "$file" | awk '{print $1}')" == "$expected" ]] \
    || fail "license file failed SHA-256 verification: $name"
done <"$MANIFEST"

echo "Bundled license check: PASS"

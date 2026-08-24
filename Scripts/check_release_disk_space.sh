#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MINIMUM_BYTES="${1:-4294967296}"
STAGE="${2:-release packaging}"

[[ "$MINIMUM_BYTES" =~ ^[0-9]+$ && "$MINIMUM_BYTES" -gt 0 ]] || {
  echo "Minimum free bytes must be a positive integer." >&2
  exit 1
}

cd "$REPOSITORY_ROOT"
AVAILABLE_KIB="$(LC_ALL=C df -Pk . | awk 'NR == 2 {print $4}')"
[[ "$AVAILABLE_KIB" =~ ^[0-9]+$ ]] || {
  echo "Unable to measure release disk space." >&2
  exit 1
}
AVAILABLE_BYTES=$((AVAILABLE_KIB * 1024))

echo "Release disk stage: $STAGE"
df -h .
for path in .build .artifacts dist; do
  [[ -e "$path" ]] && du -sh "$path"
done

if [[ "$AVAILABLE_BYTES" -lt "$MINIMUM_BYTES" ]]; then
  echo "$STAGE requires at least $MINIMUM_BYTES free bytes; $AVAILABLE_BYTES remain." >&2
  exit 1
fi

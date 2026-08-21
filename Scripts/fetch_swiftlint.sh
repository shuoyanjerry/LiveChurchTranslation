#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="0.65.0"
OUTPUT_DIR="${1:-$REPOSITORY_ROOT/.artifacts/swiftlint-$VERSION}"
ARCHIVE="SwiftLintBinary.artifactbundle.zip"
URL="https://github.com/realm/SwiftLint/releases/download/$VERSION/$ARCHIVE"
EXPECTED_SHA="eb333bd76dfb5f46d21fdf3615fe39bb938956ca0b8e94c241c4b2db6e696b90"

if [[ -x "$OUTPUT_DIR/swiftlint" ]]; then
  printf '%s\n' "$OUTPUT_DIR/swiftlint"
  exit 0
fi

TEMP_DIR="$(mktemp -d /tmp/live-church-swiftlint.XXXXXX)"
trap 'rm -rf "$TEMP_DIR"' EXIT
curl --fail --location --retry 3 --output "$TEMP_DIR/$ARCHIVE" "$URL"
ACTUAL_SHA="$(shasum -a 256 "$TEMP_DIR/$ARCHIVE" | awk '{print $1}')"
if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
  echo "SwiftLint archive checksum mismatch" >&2
  exit 1
fi

ditto -x -k "$TEMP_DIR/$ARCHIVE" "$TEMP_DIR/unpacked"
SOURCE="$(find "$TEMP_DIR/unpacked" -type f -path '*/macos/swiftlint' -print -quit)"
[[ -n "$SOURCE" && -x "$SOURCE" ]]
mkdir -p "$OUTPUT_DIR"
install -m 0755 "$SOURCE" "$OUTPUT_DIR/swiftlint"
printf '%s\n' "$OUTPUT_DIR/swiftlint"

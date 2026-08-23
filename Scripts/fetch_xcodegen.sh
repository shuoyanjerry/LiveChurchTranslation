#!/bin/bash
set -euo pipefail

fail() {
  echo "XcodeGen bootstrap failed: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION="2.45.4"
ARCHIVE_NAME="xcodegen.zip"
URL="https://github.com/yonaskolb/XcodeGen/releases/download/$VERSION/$ARCHIVE_NAME"
ARCHIVE_SHA="090ec29491aad50aec10631bf6e62253fed733c50f3aab0f5ffc86bc170bdbef"
BINARY_SHA="6aa2b4da95304b343bea12890c59f9655aa428c08b351d57d592cfab4e88a9f1"
CACHE_ROOT="$REPOSITORY_ROOT/.artifacts/xcodegen"
CACHED_ARCHIVE="$CACHE_ROOT/$ARCHIVE_NAME-$VERSION"
INSTALL_ROOT="$CACHE_ROOT/$VERSION"
BINARY="$INSTALL_ROOT/bin/xcodegen"

umask 022
mkdir -p "$CACHE_ROOT"
TEMP_DIR="$(mktemp -d "$CACHE_ROOT/.bootstrap-$VERSION.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT

if [[ -e "$CACHED_ARCHIVE" || -L "$CACHED_ARCHIVE" ]]; then
  [[ -f "$CACHED_ARCHIVE" && ! -L "$CACHED_ARCHIVE" ]] \
    || fail "cached archive is not a trusted regular file: $CACHED_ARCHIVE"
  ACTUAL_ARCHIVE_SHA="$(shasum -a 256 "$CACHED_ARCHIVE" | awk '{print $1}')"
  [[ "$ACTUAL_ARCHIVE_SHA" == "$ARCHIVE_SHA" ]] \
    || fail "cached archive checksum mismatch; remove $CACHED_ARCHIVE"
else
  [[ "${XCODEGEN_OFFLINE:-0}" != "1" ]] \
    || fail "verified XcodeGen cache is unavailable in offline mode"
  DOWNLOAD="$TEMP_DIR/$ARCHIVE_NAME"
  curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
    --output "$DOWNLOAD" "$URL"
  ACTUAL_ARCHIVE_SHA="$(shasum -a 256 "$DOWNLOAD" | awk '{print $1}')"
  [[ "$ACTUAL_ARCHIVE_SHA" == "$ARCHIVE_SHA" ]] \
    || fail "downloaded archive checksum mismatch"
  mv "$DOWNLOAD" "$CACHED_ARCHIVE"
fi

UNPACKED="$TEMP_DIR/unpacked"
mkdir -p "$UNPACKED"
unzip -q "$CACHED_ARCHIVE" -d "$UNPACKED"
VERIFIED_ROOT="$UNPACKED/xcodegen"
VERIFIED_BINARY="$VERIFIED_ROOT/bin/xcodegen"
[[ -x "$VERIFIED_BINARY" && ! -L "$VERIFIED_BINARY" ]] \
  || fail "verified archive does not contain the expected executable"
ACTUAL_BINARY_SHA="$(shasum -a 256 "$VERIFIED_BINARY" | awk '{print $1}')"
[[ "$ACTUAL_BINARY_SHA" == "$BINARY_SHA" ]] || fail "XcodeGen binary checksum mismatch"
[[ "$("$VERIFIED_BINARY" --version)" == "Version: $VERSION" ]] \
  || fail "XcodeGen version output is unexpected"

if [[ -e "$INSTALL_ROOT" || -L "$INSTALL_ROOT" ]]; then
  [[ -d "$INSTALL_ROOT" && ! -L "$INSTALL_ROOT" ]] \
    || fail "install path is not a trusted directory: $INSTALL_ROOT"
  diff -qr "$INSTALL_ROOT" "$VERIFIED_ROOT" >/dev/null \
    || fail "installed XcodeGen differs from the verified archive; remove $INSTALL_ROOT"
else
  mv "$VERIFIED_ROOT" "$INSTALL_ROOT"
fi

[[ -x "$BINARY" && ! -L "$BINARY" ]] \
  || fail "installed XcodeGen executable is missing or unsafe"
[[ "$(shasum -a 256 "$BINARY" | awk '{print $1}')" == "$BINARY_SHA" ]] \
  || fail "installed XcodeGen binary failed final verification"
printf '%s\n' "$BINARY"

#!/bin/bash

set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "usage: $0 <prepared-source-directory> <corpus-id> <expected-manifest-sha256>" >&2
    exit 64
fi

SOURCE_INPUT="$1"
CORPUS_ID="$2"
EXPECTED_MANIFEST_SHA256="$3"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
TARGET_PARENT="$PROJECT_ROOT/.artifacts/scripture-qualification"

case "$CORPUS_ID" in
    ""|.|..|*[!a-zA-Z0-9._-]*)
        echo "import: corpus-id may contain only letters, digits, dot, underscore, and hyphen" >&2
        exit 64
        ;;
esac
if [ "${#EXPECTED_MANIFEST_SHA256}" -ne 64 ]; then
    echo "import: expected manifest SHA-256 must be 64 lowercase hexadecimal characters" >&2
    exit 64
fi
case "$EXPECTED_MANIFEST_SHA256" in
    *[!0-9a-f]*)
        echo "import: expected manifest SHA-256 must be 64 lowercase hexadecimal characters" >&2
        exit 64
        ;;
esac

if [ ! -d "$SOURCE_INPUT" ]; then
    echo "import: prepared source directory does not exist" >&2
    exit 66
fi
SOURCE_ROOT="$(cd "$SOURCE_INPUT" && pwd -P)"
case "$TARGET_PARENT/" in
    "$SOURCE_ROOT/"*)
        echo "import: source must not contain the workspace target tree" >&2
        exit 65
        ;;
esac
if [ ! -f "$SOURCE_ROOT/manifest.json" ]; then
    echo "import: prepared source must contain manifest.json" >&2
    exit 66
fi
if [ -n "$(find "$SOURCE_ROOT" -type l -print -quit)" ]; then
    echo "import: source must not contain symlinks" >&2
    exit 65
fi
if [ -n "$(find "$SOURCE_ROOT" ! -type d ! -type f -print -quit)" ]; then
    echo "import: source must contain only directories and regular files" >&2
    exit 65
fi

ACTUAL_MANIFEST_SHA256="$(shasum -a 256 "$SOURCE_ROOT/manifest.json" | awk '{print $1}')"
if [ "$ACTUAL_MANIFEST_SHA256" != "$EXPECTED_MANIFEST_SHA256" ]; then
    echo "import: manifest does not match the independently supplied SHA-256" >&2
    exit 65
fi

mkdir -p "$PROJECT_ROOT/.artifacts" "$TARGET_PARENT"
chmod 0700 "$PROJECT_ROOT/.artifacts" "$TARGET_PARENT"
TARGET="$TARGET_PARENT/$CORPUS_ID"
if [ -e "$TARGET" ]; then
    echo "import: target already exists; choose a new corpus-id" >&2
    exit 73
fi

STAGING="$(mktemp -d "$TARGET_PARENT/.import-${CORPUS_ID}.XXXXXX")"
cleanup() {
    case "$STAGING" in
        "$TARGET_PARENT"/.import-*) rm -rf -- "$STAGING" ;;
        *) echo "import: refusing unsafe staging cleanup" >&2 ;;
    esac
}
trap cleanup EXIT

cp -R "$SOURCE_ROOT/." "$STAGING/"
find "$STAGING" -type d -exec chmod 0700 {} +
find "$STAGING" -type f -exec chmod 0600 {} +
swift run scripture-qualification-tool verify \
    "$STAGING" \
    "$STAGING/manifest.json" \
    "$EXPECTED_MANIFEST_SHA256"
mv "$STAGING" "$TARGET"
trap - EXIT

echo "imported verified private corpus: $TARGET"

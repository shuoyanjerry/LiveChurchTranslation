#!/bin/bash

set -euo pipefail

usage() {
    echo "usage: $0 <prepared-source-directory> <corpus-id> <expected-manifest-sha256> [-- <aggregate-only-command> ...]" >&2
    exit 64
}

[ "$#" -ge 3 ] || usage
SOURCE_INPUT="$1"
CORPUS_ID="$2"
EXPECTED_MANIFEST_SHA256="$3"
shift 3
if [ "$#" -gt 0 ]; then
    [ "$1" = "--" ] || usage
    shift
    [ "$#" -gt 0 ] || usage
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
ACTIVE_PID=""
EPHEMERAL_BASE=""
TEMP_PARENT=""

cleanup() {
    [ -n "$EPHEMERAL_BASE" ] || return 0
    case "$EPHEMERAL_BASE" in
        "$TEMP_PARENT"/live-church-scripture.*)
            if [ -e "$EPHEMERAL_BASE" ] || [ -L "$EPHEMERAL_BASE" ]; then
                chmod -R u+rwX "$EPHEMERAL_BASE" 2>/dev/null || true
                rm -rf -- "$EPHEMERAL_BASE"
            fi
            ;;
        *) echo "qualification: refusing unsafe temporary cleanup" >&2 ;;
    esac
}

handle_signal() {
    local status="$1"
    if [ -n "$ACTIVE_PID" ]; then
        kill -TERM "$ACTIVE_PID" 2>/dev/null || true
        wait "$ACTIVE_PID" 2>/dev/null || true
    fi
    cleanup
    exit "$status"
}

run_child() {
    local status
    set +e
    "$@" &
    ACTIVE_PID="$!"
    wait "$ACTIVE_PID"
    status="$?"
    ACTIVE_PID=""
    set -e
    return "$status"
}

trap cleanup EXIT
trap 'handle_signal 129' HUP
trap 'handle_signal 130' INT
trap 'handle_signal 143' TERM

case "$CORPUS_ID" in
    ""|.|..|*[!a-zA-Z0-9._-]*) usage ;;
esac
if [ "${#EXPECTED_MANIFEST_SHA256}" -ne 64 ]; then
    usage
fi
case "$EXPECTED_MANIFEST_SHA256" in
    *[!0-9a-f]*) usage ;;
esac
[ -d "$SOURCE_INPUT" ] || { echo "qualification: source directory is missing" >&2; exit 66; }
SOURCE_ROOT="$(cd "$SOURCE_INPUT" && pwd -P)"
case "$SOURCE_ROOT/" in
    "$PROJECT_ROOT/"*)
        echo "qualification: prepared corpus must stay outside the workspace" >&2
        exit 65
        ;;
esac
case "$PROJECT_ROOT/" in
    "$SOURCE_ROOT/"*)
        echo "qualification: source must not contain the workspace" >&2
        exit 65
        ;;
esac
[ -f "$SOURCE_ROOT/manifest.json" ] \
    || { echo "qualification: source must contain manifest.json" >&2; exit 66; }
[ -z "$(find "$SOURCE_ROOT" -type l -print -quit)" ] \
    || { echo "qualification: source must not contain symlinks" >&2; exit 65; }
[ -z "$(find "$SOURCE_ROOT" ! -type d ! -type f -print -quit)" ] \
    || { echo "qualification: source contains a special file" >&2; exit 65; }

ACTUAL_MANIFEST_SHA256="$(shasum -a 256 "$SOURCE_ROOT/manifest.json" | awk '{print $1}')"
[ "$ACTUAL_MANIFEST_SHA256" = "$EXPECTED_MANIFEST_SHA256" ] \
    || { echo "qualification: external manifest SHA-256 mismatch" >&2; exit 65; }

TEMP_INPUT="${TMPDIR:-/tmp}"
[ -d "$TEMP_INPUT" ] || { echo "qualification: temporary parent is missing" >&2; exit 73; }
TEMP_PARENT="$(cd "$TEMP_INPUT" && pwd -P)"
EPHEMERAL_BASE="$(mktemp -d "$TEMP_PARENT/live-church-scripture.XXXXXX")"
chmod 0700 "$EPHEMERAL_BASE"
CORPUS_ROOT="$EPHEMERAL_BASE/.artifacts/scripture-qualification/$CORPUS_ID"
mkdir -m 0700 "$EPHEMERAL_BASE/.artifacts"
mkdir -m 0700 "$EPHEMERAL_BASE/.artifacts/scripture-qualification"
mkdir -m 0700 "$CORPUS_ROOT"
cp -R "$SOURCE_ROOT/." "$CORPUS_ROOT/"
find "$CORPUS_ROOT" -type d -exec chmod 0700 {} +
find "$CORPUS_ROOT" -type f -exec chmod 0600 {} +

run_child swift run --package-path "$PROJECT_ROOT" scripture-qualification-tool verify \
    "$CORPUS_ROOT" \
    "$CORPUS_ROOT/manifest.json" \
    "$EXPECTED_MANIFEST_SHA256"

if [ "$#" -gt 0 ]; then
    run_child env \
        SCRIPTURE_QUALIFICATION_ROOT="$CORPUS_ROOT" \
        SCRIPTURE_QUALIFICATION_MANIFEST="$CORPUS_ROOT/manifest.json" \
        SCRIPTURE_QUALIFICATION_MANIFEST_SHA256="$EXPECTED_MANIFEST_SHA256" \
        SCRIPTURE_QUALIFICATION_AGGREGATE_ONLY=1 \
        "$@"
fi

cleanup
EPHEMERAL_BASE=""
echo "ephemeral Scripture qualification finished; temporary corpus removed"

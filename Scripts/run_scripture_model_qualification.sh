#!/bin/bash

set -euo pipefail

usage() {
    echo "usage: $0 <prepared-source-directory> <corpus-id> <manifest-sha256> <report-filename.json>" >&2
    exit 64
}

[ "$#" -eq 4 ] || usage
SOURCE_INPUT="$1"
CORPUS_ID="$2"
MANIFEST_SHA256="$3"
REPORT_FILENAME="$4"

case "$REPORT_FILENAME" in
    ""|.*|*..*|*[!a-zA-Z0-9._-]*|*.json/) usage ;;
esac
case "$REPORT_FILENAME" in
    *.json) ;;
    *) usage ;;
esac

: "${QWEN_MODEL_DIR:?QWEN_MODEL_DIR is required}"
: "${HYMT_MODEL_DIR:?HYMT_MODEL_DIR is required}"
: "${HYMT_LLAMA_SERVER:?HYMT_LLAMA_SERVER is required}"
: "${SCRIPTURE_QUALIFICATION_PHASE:?SCRIPTURE_QUALIFICATION_PHASE is required}"
case "$SCRIPTURE_QUALIFICATION_PHASE" in
    development|sealed) ;;
    *) usage ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
REPORT_URL="$PROJECT_ROOT/.artifacts/scripture-qualification-reports/$REPORT_FILENAME"

exec env SCRIPTURE_QUALIFICATION_REPORT="$REPORT_URL" \
    "$SCRIPT_DIR/run_ephemeral_scripture_qualification.sh" \
    "$SOURCE_INPUT" "$CORPUS_ID" "$MANIFEST_SHA256" \
    -- swift test --package-path "$PROJECT_ROOT" --filter ScriptureModelQualificationTests

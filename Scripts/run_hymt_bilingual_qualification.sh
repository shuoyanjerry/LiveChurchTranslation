#!/bin/bash

set -euo pipefail
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
cd "$PROJECT_ROOT"

: "${HYMT_MODEL_DIR:?HYMT_MODEL_DIR is required}"
: "${HYMT_LLAMA_SERVER:?HYMT_LLAMA_SERVER is required}"
: "${BILINGUAL_TRANSLATION_MANIFEST:?BILINGUAL_TRANSLATION_MANIFEST is required}"
: "${BILINGUAL_TRANSLATION_REPORT:?BILINGUAL_TRANSLATION_REPORT is required}"

PRIVATE_QA_EVIDENCE_ROOT="${PRIVATE_QA_EVIDENCE_ROOT:-.artifacts/sermon-corpus}" \
    "$SCRIPT_DIR/check_private_qa_boundaries.sh"

if [ "${#BILINGUAL_TRANSLATION_REPORT}" -gt 128 ] \
    || [[ ! "$BILINGUAL_TRANSLATION_REPORT" =~ ^[[:alnum:]][[:alnum:]_.-]*\.json$ ]] \
    || [[ "$BILINGUAL_TRANSLATION_REPORT" == *..* ]]; then
    echo "qualification: private report filename is invalid" >&2
    exit 1
fi
REPORT_PATH="$PROJECT_ROOT/.artifacts/translation-qualification/$BILINGUAL_TRANSLATION_REPORT"
SIDECAR_PATH="$REPORT_PATH.postflight.json"
if [ -e "$REPORT_PATH" ] || [ -L "$REPORT_PATH" ] \
    || [ -e "$SIDECAR_PATH" ] || [ -L "$SIDECAR_PATH" ]; then
    echo "qualification: private report or postflight destination already exists" >&2
    exit 1
fi

bootstrap() {
    env \
        TRANSLATION_QUALIFICATION_BOOTSTRAP=1 \
        TRANSLATION_QUALIFICATION_WORKSPACE_ROOT="$PROJECT_ROOT" \
        swift test -c release \
        --filter HyMTProvenanceBootstrapTests \
        -Xswiftc -warnings-as-errors
}

value_from() {
    local output="$1"
    local key="$2"
    printf '%s\n' "$output" | awk -F= -v key="$key" '$1 == key { value = $2 } END { print value }'
}

first_output="$(bootstrap)"
first_source="$(value_from "$first_output" HYMT_SOURCE_BUNDLE_SHA256)"
first_binary="$(value_from "$first_output" HYMT_TEST_EXECUTABLE_SHA256)"

second_output="$(bootstrap)"
second_source="$(value_from "$second_output" HYMT_SOURCE_BUNDLE_SHA256)"
second_binary="$(value_from "$second_output" HYMT_TEST_EXECUTABLE_SHA256)"

if [ -z "$first_source" ] || [ -z "$first_binary" ] \
    || [ "$first_source" != "$second_source" ] \
    || [ "$first_binary" != "$second_binary" ] \
    || [[ ! "$second_source" =~ ^[0-9a-f]{64}$ ]] \
    || [[ ! "$second_binary" =~ ^[0-9a-f]{64}$ ]]; then
    echo "qualification: release build provenance was missing or changed" >&2
    exit 1
fi

set +e
env \
    TRANSLATION_QUALIFICATION_WORKSPACE_ROOT="$PROJECT_ROOT" \
    TRANSLATION_QUALIFICATION_SOURCE_BUNDLE_SHA256="$second_source" \
    TRANSLATION_QUALIFICATION_TEST_EXECUTABLE_SHA256="$second_binary" \
    swift test -c release --skip-build \
    --filter HyMTBilingualSermonQualificationTests \
    -Xswiftc -warnings-as-errors
qualification_status=$?
set -e

set +e
env \
    TRANSLATION_QUALIFICATION_POSTFLIGHT=1 \
    TRANSLATION_QUALIFICATION_WORKSPACE_ROOT="$PROJECT_ROOT" \
    TRANSLATION_QUALIFICATION_SOURCE_BUNDLE_SHA256="$second_source" \
    TRANSLATION_QUALIFICATION_TEST_EXECUTABLE_SHA256="$second_binary" \
    swift test -c release --skip-build \
    --filter HyMTQualificationPostflightTests \
    -Xswiftc -warnings-as-errors
postflight_status=$?
set -e

if [ "$postflight_status" -ne 0 ]; then
    echo "qualification: postflight release-input verification failed" >&2
    exit 1
fi
exit "$qualification_status"

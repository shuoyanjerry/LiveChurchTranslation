#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
TEST_PARENT="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
TEST_ROOT="$(mktemp -d "$TEST_PARENT/scripture-lifecycle-test.XXXXXX")"
RUNTIME_PARENT="$TEST_ROOT/runtime"
SOURCE_ROOT="$TEST_ROOT/prepared"
FAKE_BIN="$TEST_ROOT/bin"
RUNNER="$SCRIPT_DIR/run_ephemeral_scripture_qualification.sh"

cleanup() {
    case "$TEST_ROOT" in
        "$TEST_PARENT"/scripture-lifecycle-test.*) rm -rf -- "$TEST_ROOT" ;;
        *) echo "ephemeral lifecycle test: refusing unsafe cleanup" >&2 ;;
    esac
}
trap cleanup EXIT

mkdir -m 0700 "$RUNTIME_PARENT" "$SOURCE_ROOT" "$FAKE_BIN"
mkdir -m 0700 "$SOURCE_ROOT/declarations" "$SOURCE_ROOT/audio" "$SOURCE_ROOT/reference"
printf '%s\n' '{"synthetic":"manifest"}' > "$SOURCE_ROOT/manifest.json"
printf '%s\n' 'synthetic declaration' > "$SOURCE_ROOT/declarations/source.txt"
printf '%s\n' 'synthetic audio' > "$SOURCE_ROOT/audio/source.wav"
printf '%s\n' 'synthetic reference' > "$SOURCE_ROOT/reference/source.txt"
cp "$SCRIPT_DIR/TestFixtures/FakeScriptureQualificationSwift.sh" "$FAKE_BIN/swift"
chmod 0700 "$FAKE_BIN/swift"
EXPECTED_SHA256="$(shasum -a 256 "$SOURCE_ROOT/manifest.json" | awk '{print $1}')"
SOURCE_SNAPSHOT="$(
    find "$SOURCE_ROOT" -type f -print | sort \
        | while IFS= read -r file; do shasum -a 256 "$file"; done \
        | shasum -a 256 | awk '{print $1}'
)"

assert_removed() {
    local record="$1"
    local root
    [ -s "$record" ] || { echo "ephemeral lifecycle test: missing root record" >&2; exit 1; }
    root="$(sed -n '1p' "$record")"
    [ ! -e "$root" ] || { echo "ephemeral lifecycle test: corpus remained" >&2; exit 1; }
    [ -z "$(find "$RUNTIME_PARENT" -maxdepth 1 -name 'live-church-scripture.*' -print -quit)" ] \
        || { echo "ephemeral lifecycle test: temporary base remained" >&2; exit 1; }
    [ ! -e "$PROJECT_ROOT/.artifacts/scripture-qualification/ephemeral-test" ] \
        || { echo "ephemeral lifecycle test: workspace corpus was created" >&2; exit 1; }
    [ -d "$SOURCE_ROOT" ] \
        || { echo "ephemeral lifecycle test: prepared source was removed" >&2; exit 1; }
    local source_snapshot
    source_snapshot="$(
        find "$SOURCE_ROOT" -type f -print | sort \
            | while IFS= read -r file; do shasum -a 256 "$file"; done \
            | shasum -a 256 | awk '{print $1}'
    )"
    [ "$source_snapshot" = "$SOURCE_SNAPSHOT" ] \
        || { echo "ephemeral lifecycle test: prepared source changed" >&2; exit 1; }
}

run_expect_status() {
    local expected="$1"
    shift
    local status
    set +e
    "$@" >/dev/null 2>&1
    status="$?"
    set -e
    [ "$status" -eq "$expected" ] \
        || { echo "ephemeral lifecycle test: expected $expected, got $status" >&2; exit 1; }
}

success_record="$TEST_ROOT/success-root"
PATH="$FAKE_BIN:$PATH" TMPDIR="$RUNTIME_PARENT" \
    FAKE_PREFLIGHT_ROOT_RECORD="$success_record" ROOT_RECORD="$success_record.command" \
    "$RUNNER" "$SOURCE_ROOT" ephemeral-test "$EXPECTED_SHA256" -- \
    /bin/sh -c '
        test "$SCRIPTURE_QUALIFICATION_AGGREGATE_ONLY" = 1
        test "$SCRIPTURE_QUALIFICATION_MANIFEST" = "$SCRIPTURE_QUALIFICATION_ROOT/manifest.json"
        test "$(shasum -a 256 "$SCRIPTURE_QUALIFICATION_MANIFEST" | awk '\''{print $1}'\'')" = "$SCRIPTURE_QUALIFICATION_MANIFEST_SHA256"
        printf "%s\n" "$SCRIPTURE_QUALIFICATION_ROOT" > "$ROOT_RECORD"
    '
assert_removed "$success_record"
[ -s "$success_record.command" ]
[ "$(sed -n '1p' "$success_record")" = "$(sed -n '1p' "$success_record.command")" ]

preflight_record="$TEST_ROOT/preflight-failure-root"
run_expect_status 27 env PATH="$FAKE_BIN:$PATH" TMPDIR="$RUNTIME_PARENT" \
    FAKE_PREFLIGHT_ROOT_RECORD="$preflight_record" FAKE_PREFLIGHT_EXIT=27 \
    "$RUNNER" "$SOURCE_ROOT" ephemeral-test "$EXPECTED_SHA256"
assert_removed "$preflight_record"

command_record="$TEST_ROOT/command-failure-root"
run_expect_status 42 env PATH="$FAKE_BIN:$PATH" TMPDIR="$RUNTIME_PARENT" \
    FAKE_PREFLIGHT_ROOT_RECORD="$command_record" ROOT_RECORD="$command_record.command" \
    "$RUNNER" "$SOURCE_ROOT" ephemeral-test "$EXPECTED_SHA256" -- \
    /bin/sh -c 'printf "%s\n" "$SCRIPTURE_QUALIFICATION_ROOT" > "$ROOT_RECORD"; exit 42'
assert_removed "$command_record"

signal_record="$TEST_ROOT/signal-root"
run_expect_status 143 env PATH="$FAKE_BIN:$PATH" TMPDIR="$RUNTIME_PARENT" \
    FAKE_PREFLIGHT_ROOT_RECORD="$signal_record" ROOT_RECORD="$signal_record.command" \
    "$RUNNER" "$SOURCE_ROOT" ephemeral-test "$EXPECTED_SHA256" -- \
    /bin/sh -c 'printf "%s\n" "$SCRIPTURE_QUALIFICATION_ROOT" > "$ROOT_RECORD"; kill -TERM "$PPID"; sleep 2'
assert_removed "$signal_record"

echo "Ephemeral Scripture qualification lifecycle tests passed."

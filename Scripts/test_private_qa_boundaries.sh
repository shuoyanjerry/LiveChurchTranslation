#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
ARTIFACT_ROOT="$PROJECT_ROOT/.artifacts"
CHECKER="$SCRIPT_DIR/check_private_qa_boundaries.sh"

mkdir -p "$ARTIFACT_ROOT"
TEST_ROOT="$(mktemp -d "$ARTIFACT_ROOT/private-boundary-test.XXXXXX")"

cleanup() {
    case "$TEST_ROOT" in
        "$ARTIFACT_ROOT"/private-boundary-test.*)
            find "$TEST_ROOT" -type d -exec chmod 0700 {} + 2>/dev/null || true
            rm -rf -- "$TEST_ROOT"
            ;;
        *) echo "private boundary test: refusing unsafe cleanup" >&2 ;;
    esac
}
trap cleanup EXIT

expect_pass() {
    local label="$1"
    shift
    if ! env -u PRIVATE_QA_EVIDENCE_ROOT "$@" >/dev/null 2>&1; then
        echo "private boundary test failed: expected pass for $label" >&2
        exit 1
    fi
}

expect_fail() {
    local label="$1"
    shift
    if env -u PRIVATE_QA_EVIDENCE_ROOT "$@" >/dev/null 2>&1; then
        echo "private boundary test failed: expected rejection for $label" >&2
        exit 1
    fi
}

good_root="$TEST_ROOT/good"
mkdir -m 0700 "$good_root"
: > "$good_root/evidence.json"
chmod 0600 "$good_root/evidence.json"

expect_pass "no opt-in root" "$CHECKER"
expect_pass "positional root" "$CHECKER" "$good_root"
if ! PRIVATE_QA_EVIDENCE_ROOT="$good_root" "$CHECKER" >/dev/null 2>&1; then
    echo "private boundary test failed: expected pass for environment root" >&2
    exit 1
fi
if PRIVATE_QA_EVIDENCE_ROOT="" "$CHECKER" >/dev/null 2>&1; then
    echo "private boundary test failed: expected rejection for empty environment root" >&2
    exit 1
fi

bad_directory="$TEST_ROOT/bad-directory"
mkdir -m 0755 "$bad_directory"
expect_fail "directory mode" "$CHECKER" "$bad_directory"

nested_bad_directory="$TEST_ROOT/nested-bad-directory"
mkdir -m 0700 "$nested_bad_directory"
mkdir -m 0000 "$nested_bad_directory/closed"
expect_fail "nested directory mode" "$CHECKER" "$nested_bad_directory"

bad_file="$TEST_ROOT/bad-file"
mkdir -m 0700 "$bad_file"
: > "$bad_file/evidence.json"
chmod 0644 "$bad_file/evidence.json"
expect_fail "file mode" "$CHECKER" "$bad_file"

symlink_tree="$TEST_ROOT/symlink-tree"
mkdir -m 0700 "$symlink_tree"
ln -s "$good_root/evidence.json" "$symlink_tree/evidence-link"
expect_fail "nested symlink" "$CHECKER" "$symlink_tree"

root_link="$TEST_ROOT/root-link"
ln -s "$good_root" "$root_link"
expect_fail "root symlink" "$CHECKER" "$root_link"
expect_fail "outside workspace" "$CHECKER" "/tmp"
expect_fail "missing explicit root" "$CHECKER" "$TEST_ROOT/missing"
expect_fail "parent traversal" "$CHECKER" ".artifacts/../Sources"

non_file_tree="$TEST_ROOT/non-file"
mkdir -m 0700 "$non_file_tree"
mkfifo "$non_file_tree/evidence-pipe"
expect_fail "non-file node" "$CHECKER" "$non_file_tree"

echo "Private-QA boundary tests passed."

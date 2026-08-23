#!/bin/bash

set -euo pipefail

# Opt in to permission checks with positional roots or PRIVATE_QA_EVIDENCE_ROOT.
# Every opted-in root must already exist beneath this workspace's .artifacts tree.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
cd "$PROJECT_ROOT"

private_roots=(
    ".artifacts"
    "tmp/pdfs/argyle-golden"
)

if [ -n "$(git ls-files -- "${private_roots[@]}")" ]; then
    echo "privacy: private-QA material is tracked by Git" >&2
    exit 1
fi

for root in "${private_roots[@]}"; do
    if ! git check-ignore --quiet --no-index "$root/privacy-boundary-probe"; then
        echo "privacy: a private-QA root is not protected by .gitignore" >&2
        exit 1
    fi
done

artifact_root="$PROJECT_ROOT/.artifacts"

permission_failure() {
    local ordinal="$1"
    local reason="$2"
    echo "privacy: opted-in evidence root $ordinal $reason" >&2
    exit 1
}

find_has_match() {
    local candidate="$1"
    local ordinal="$2"
    local match
    shift 2
    match="$(find "$candidate" "$@" -print -quit 2>/dev/null)" \
        || permission_failure "$ordinal" "cannot be inspected"
    [ -n "$match" ]
}

check_private_permissions() {
    local requested="$1"
    local ordinal="$2"
    local candidate physical

    [ -n "$requested" ] || permission_failure "$ordinal" "is empty"
    case "/$requested/" in
        */../*) permission_failure "$ordinal" "contains parent traversal" ;;
    esac
    requested="${requested%/}"
    case "$requested" in
        .artifacts)
            candidate="$artifact_root"
            ;;
        .artifacts/*)
            candidate="$PROJECT_ROOT/$requested"
            ;;
        "$artifact_root"|"$artifact_root"/*)
            candidate="$requested"
            ;;
        *)
            permission_failure "$ordinal" "is outside the workspace artifacts tree"
            ;;
    esac

    [ -d "$candidate" ] || permission_failure "$ordinal" "is not an existing directory"
    physical="$(cd "$candidate" 2>/dev/null && pwd -P)" \
        || permission_failure "$ordinal" "cannot be resolved"
    [ "$physical" = "$candidate" ] \
        || permission_failure "$ordinal" "uses a symlinked path"
    if find_has_match "$candidate" "$ordinal" -type d ! -perm 0700; then
        permission_failure "$ordinal" "contains a directory whose mode is not 0700"
    fi
    if find_has_match "$candidate" "$ordinal" -type f ! -perm 0600; then
        permission_failure "$ordinal" "contains a file whose mode is not 0600"
    fi
    if find_has_match "$candidate" "$ordinal" -type l; then
        permission_failure "$ordinal" "contains a symlink"
    fi
    if find_has_match "$candidate" "$ordinal" ! -type d ! -type f; then
        permission_failure "$ordinal" "contains a non-file node"
    fi
}

ordinal=0
for root in "$@"; do
    ordinal=$((ordinal + 1))
    check_private_permissions "$root" "$ordinal"
done
if [ "${PRIVATE_QA_EVIDENCE_ROOT+x}" = x ]; then
    ordinal=$((ordinal + 1))
    check_private_permissions "$PRIVATE_QA_EVIDENCE_ROOT" "$ordinal"
fi

if [ -n "$(git status --porcelain --untracked-files=all -- "${private_roots[@]}")" ]; then
    echo "privacy: private-QA material is visible to Git" >&2
    exit 1
fi

echo "Private-QA Git boundary checks passed."
if [ "$ordinal" -gt 0 ]; then
    echo "Private-QA evidence permission checks passed for $ordinal opted-in root(s)."
fi

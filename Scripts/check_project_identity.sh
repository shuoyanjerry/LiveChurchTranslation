#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

EXPECTED_NAME="shuoyanjerry"
EXPECTED_EMAIL="jerryyanshuo@outlook.com"
EXPECTED_AUTHOR_LINE="- $EXPECTED_NAME <$EXPECTED_EMAIL>"
FORBIDDEN_TOOL_NAME="co""dex"

if git ls-files | rg --ignore-case --fixed-strings "$FORBIDDEN_TOOL_NAME"; then
    echo "A tracked path contains the forbidden tool name." >&2
    exit 1
fi

if git grep --ignore-case --fixed-strings --line-number -a "$FORBIDDEN_TOOL_NAME" -- .; then
    echo "Tracked repository text contains the forbidden tool name." >&2
    exit 1
fi

while IFS= read -r revision; do
    if git ls-tree -r --name-only "$revision" \
        | rg --ignore-case --fixed-strings "$FORBIDDEN_TOOL_NAME"; then
        echo "Git history contains a forbidden tracked path at $revision." >&2
        exit 1
    fi
    if git grep --ignore-case --fixed-strings --line-number -a \
        "$FORBIDDEN_TOOL_NAME" "$revision" -- .; then
        echo "Git history contains forbidden repository text at $revision." >&2
        exit 1
    fi
done < <(git rev-list refs/heads/main)

if git log refs/heads/main --format='%B' | rg --ignore-case --fixed-strings "$FORBIDDEN_TOOL_NAME"; then
    echo "Git history contains a forbidden commit message." >&2
    exit 1
fi

if [[ "$(rg --count '^-' AUTHORS.md)" != "1" ]] \
    || ! rg --fixed-strings --line-regexp -- "$EXPECTED_AUTHOR_LINE" AUTHORS.md >/dev/null; then
    echo "AUTHORS.md must identify exactly one project developer." >&2
    exit 1
fi

if ! rg --fixed-strings "Copyright (c) 2026 $EXPECTED_NAME" LICENSE >/dev/null; then
    echo "LICENSE developer identity is inconsistent." >&2
    exit 1
fi

unexpected_identity="$({
    git log refs/heads/main --format='%an%x09%ae%n%cn%x09%ce'
} | awk -F '\t' -v name="$EXPECTED_NAME" -v email="$EXPECTED_EMAIL" \
    '$1 != name || $2 != email { print }')"
if [[ -n "$unexpected_identity" ]]; then
    echo "Git history contains an unexpected project author or committer:" >&2
    echo "$unexpected_identity" >&2
    exit 1
fi

echo "Project identity checks passed."

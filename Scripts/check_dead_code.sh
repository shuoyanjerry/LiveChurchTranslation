#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

swift "$SCRIPT_DIR/DeadCodeCheck.swift" "$PROJECT_ROOT"

if command -v periphery >/dev/null 2>&1; then
    periphery scan --strict --retain-public --exclude-tests --disable-update-check
else
    echo "Periphery is not installed; deterministic static approximation completed."
fi

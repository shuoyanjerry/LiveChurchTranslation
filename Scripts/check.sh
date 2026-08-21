#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

"$SCRIPT_DIR/check_architecture.sh"

swift format lint --recursive --strict --configuration .swift-format \
    Sources Tests Package.swift Scripts/ArchitectureCheck.swift Scripts/DeadCodeCheck.swift

if command -v swiftlint >/dev/null 2>&1; then
    SWIFTLINT_EXECUTABLE="$(command -v swiftlint)"
else
    SWIFTLINT_EXECUTABLE="$("$SCRIPT_DIR/fetch_swiftlint.sh")"
fi
if [[ "$(xcode-select --print-path)" == "/Library/Developer/CommandLineTools" ]]; then
    env DYLD_FRAMEWORK_PATH=/Library/Developer/CommandLineTools/usr/lib \
        "$SWIFTLINT_EXECUTABLE" lint --strict --config .swiftlint.yml
else
    "$SWIFTLINT_EXECUTABLE" lint --strict --config .swiftlint.yml
fi

swift build -Xswiftc -warnings-as-errors
swift test -Xswiftc -warnings-as-errors
"$SCRIPT_DIR/check_dead_code.sh"

echo "All local quality gates passed."

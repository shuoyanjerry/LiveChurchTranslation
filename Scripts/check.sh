#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

active_gate="quality-gate bootstrap"
report_gate_failure() {
    result=$?
    if [[ "$result" -ne 0 && "${GITHUB_ACTIONS:-}" == "true" ]]; then
        printf '::error title=Quality gate failed::%s\n' "$active_gate"
    fi
}
trap report_gate_failure EXIT

active_gate="architecture"
"$SCRIPT_DIR/check_architecture.sh"
active_gate="ephemeral Scripture qualification"
"$SCRIPT_DIR/test_ephemeral_scripture_qualification.sh"
active_gate="App Store packaging"
"$SCRIPT_DIR/check_app_store_packaging.sh"
active_gate="generated Xcode project"
"$SCRIPT_DIR/check_xcode_project.sh"

active_gate="swift-format"
swift format lint --recursive --strict --configuration .swift-format \
    Sources Tests Package.swift Scripts/ArchitectureCheck.swift Scripts/DeadCodeCheck.swift

active_gate="SwiftLint"
if command -v swiftlint >/dev/null 2>&1; then
    SWIFTLINT_EXECUTABLE="$(command -v swiftlint)"
else
    SWIFTLINT_EXECUTABLE="$("$SCRIPT_DIR/fetch_swiftlint.sh")"
fi
SWIFTLINT_ARGUMENTS=(lint --strict --no-cache --config .swiftlint.yml)
if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
    SWIFTLINT_ARGUMENTS+=(--reporter github-actions-logging)
fi
if [[ "$(xcode-select --print-path)" == "/Library/Developer/CommandLineTools" ]]; then
    env DYLD_FRAMEWORK_PATH=/Library/Developer/CommandLineTools/usr/lib \
        "$SWIFTLINT_EXECUTABLE" "${SWIFTLINT_ARGUMENTS[@]}"
else
    "$SWIFTLINT_EXECUTABLE" "${SWIFTLINT_ARGUMENTS[@]}"
fi

active_gate="endpoint packet tests"
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
    -s Tests/EndpointHumanLabelPacketTests -p 'test_*.py' -v

active_gate="Swift build"
swift build -Xswiftc -warnings-as-errors
active_gate="Swift tests"
swift test -Xswiftc -warnings-as-errors
active_gate="dead-code analysis"
"$SCRIPT_DIR/check_dead_code.sh"

trap - EXIT
echo "All local quality gates passed."

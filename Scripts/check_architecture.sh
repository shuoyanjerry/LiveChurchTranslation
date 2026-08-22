#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

failures=0

report_failure() {
    echo "architecture: $1" >&2
    failures=$((failures + 1))
}

while IFS= read -r file; do
    lines="$(awk 'END { print NR }' "$file")"
    if [ "$lines" -ge 200 ]; then
        report_failure "$file has $lines lines; source files must stay below 200"
    fi
done < <(
    find Sources Tests -type f \
        \( -name '*.swift' -o -name '*.c' -o -name '*.h' -o -name '*.html' \
        -o -name '*.css' -o -name '*.js' \) -print \
        | rg -v '^Sources/WebRTCVADC/Vendor/' \
        | sort
)

while IFS= read -r path; do
    [ -z "$path" ] || report_failure "garbage-drawer name is forbidden: $path"
done < <(find Sources -mindepth 1 \( -type d -o -type f \) \
    | rg -v '^Sources/WebRTCVADC/Vendor/' \
    | rg -i '/(shared|common|utils|utilities)([./]|$)' || true)

for directory in Sources/*API; do
    [ -d "$directory" ] || continue
    if rg -n '^import (AppKit|AVFoundation|CoreML|Metal|MLX|OSLog|SQLite3|SwiftUI|Translation)\b' \
        "$directory" -g '*.swift'; then
        report_failure "$directory imports an implementation or UI framework"
    fi
done

for module in AudioProcessingCore GlossaryCore SessionManagement TranscriptCore VADCore; do
    directory="Sources/$module"
    [ -d "$directory" ] || continue
    if rg -n '^import (AppKit|AVFoundation|CoreML|Metal|MLX|OSLog|SQLite3|SwiftUI|Translation)\b' \
        "$directory" -g '*.swift'; then
        report_failure "$module business code imports an infrastructure or UI framework"
    fi
    if rg -n '\.(default|shared|standard)\b' "$directory" -g '*.swift'; then
        report_failure "$module business code accesses a process-wide system instance"
    fi
done

if rg -n 'static\s+(let|var)\s+(default|shared|standard)\b|nonisolated\(unsafe\)' \
    Sources -g '*.swift'; then
    report_failure "global singleton or unsafe global mutable state is forbidden"
fi

if [ ! -d Sources/ChurchTranslatorApp ]; then
    report_failure "ChurchTranslatorApp composition-root target is missing"
else
    main_count="$(rg -l '@main\b' Sources/ChurchTranslatorApp -g '*.swift' | wc -l | tr -d ' ')"
    [ "$main_count" -eq 1 ] || report_failure "ChurchTranslatorApp must contain exactly one @main declaration"
    if rg -n '^\s*(public\s+)?(actor|protocol)\b|@Published\b' \
        Sources/ChurchTranslatorApp -g '*.swift'; then
        report_failure "ChurchTranslatorApp may wire dependencies but must not define business services or state"
    fi
fi

if ! swift package dump-package | swift "$SCRIPT_DIR/ArchitectureCheck.swift"; then
    failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
    echo "Architecture checks failed with $failures violation group(s)." >&2
    exit 1
fi

echo "Architecture checks passed."

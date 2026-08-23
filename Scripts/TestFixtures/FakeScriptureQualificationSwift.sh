#!/bin/bash

set -euo pipefail

[ "$#" -eq 8 ]
[ "$1" = "run" ]
[ "$2" = "--package-path" ]
[ -n "$3" ]
[ "$4" = "scripture-qualification-tool" ]
[ "$5" = "verify" ]
CORPUS_ROOT="$6"
MANIFEST="$7"
EXPECTED_SHA256="$8"

case "$CORPUS_ROOT" in
    */.artifacts/scripture-qualification/ephemeral-test) ;;
    *) exit 91 ;;
esac
[ "$MANIFEST" = "$CORPUS_ROOT/manifest.json" ]
[ "$(stat -f '%Lp' "$CORPUS_ROOT")" = "700" ]
[ -z "$(find "$CORPUS_ROOT" -type d ! -perm 0700 -print -quit)" ]
[ -z "$(find "$CORPUS_ROOT" -type f ! -perm 0600 -print -quit)" ]
[ "$(shasum -a 256 "$MANIFEST" | awk '{print $1}')" = "$EXPECTED_SHA256" ]

if [ -n "${FAKE_PREFLIGHT_ROOT_RECORD:-}" ]; then
    printf '%s\n' "$CORPUS_ROOT" > "$FAKE_PREFLIGHT_ROOT_RECORD"
fi
if [ "${FAKE_PREFLIGHT_SIGNAL_PARENT:-0}" = "1" ]; then
    kill -TERM "$PPID"
    sleep 2
fi
exit "${FAKE_PREFLIGHT_EXIT:-0}"

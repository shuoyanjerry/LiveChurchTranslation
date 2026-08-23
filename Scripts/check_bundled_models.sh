#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="${1:-}"
[[ -n "$APP" && -d "$APP" && ! -L "$APP" ]] || {
  echo "usage: $0 /path/to/Application.app" >&2
  exit 1
}
"$SCRIPT_DIR/check_release_models.sh" "$APP/Contents/Resources/Models"

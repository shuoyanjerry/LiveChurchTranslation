#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP="$REPOSITORY_ROOT/dist/Quiet Liturgy Reader.app"
DMG="$REPOSITORY_ROOT/dist/Quiet Liturgy Reader.dmg"
IDENTITY="${DEVELOPER_ID_APPLICATION:--}"
MAX_RELEASE_ASSET_BYTES=2147483648

[[ -d "$APP" ]] || "$SCRIPT_DIR/package_release.sh"
"$SCRIPT_DIR/audit_release_app.sh" "$APP" "$IDENTITY"
STAGING="$(mktemp -d /tmp/live-church-dmg.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/Quiet Liturgy Reader.app"
ln -s /Applications "$STAGING/Applications"

if [[ -e "$DMG" ]]; then
  [[ "$DMG" == "$REPOSITORY_ROOT/dist/Quiet Liturgy Reader.dmg" ]]
  rm -f "$DMG"
fi
hdiutil create \
  -volname "Quiet Liturgy Reader" \
  -srcfolder "$STAGING" \
  -format UDZO \
  -ov "$DMG"

if [[ "$IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$IDENTITY" "$DMG"
fi
hdiutil verify "$DMG"
DMG_BYTES="$(stat -f '%z' "$DMG")"
if [[ "$DMG_BYTES" -ge "$MAX_RELEASE_ASSET_BYTES" ]]; then
  echo "DMG is $DMG_BYTES bytes; GitHub Release assets must be smaller than 2 GiB." >&2
  exit 1
fi
echo "DMG bytes: $DMG_BYTES (limit: less than $MAX_RELEASE_ASSET_BYTES)"
echo "Created $DMG"

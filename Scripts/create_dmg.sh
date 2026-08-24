#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP="$REPOSITORY_ROOT/dist/Live Church Translation.app"
DMG="$REPOSITORY_ROOT/dist/Live Church Translation.dmg"
IDENTITY="${DEVELOPER_ID_APPLICATION:--}"
MAX_RELEASE_ASSET_BYTES=2147483648

"$SCRIPT_DIR/check_app_store_packaging.sh"
[[ -d "$APP" ]] || "$SCRIPT_DIR/package_release.sh"
"$SCRIPT_DIR/audit_release_app.sh" "$APP" "$IDENTITY"
"$SCRIPT_DIR/check_release_disk_space.sh" 5368709120 \
  "before DMG creation and drag-install audit"
STAGING="$(mktemp -d /tmp/live-church-dmg.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT
ditto --clone "$APP" "$STAGING/Live Church Translation.app"
ln -s /Applications "$STAGING/Applications"

if [[ -e "$DMG" ]]; then
  [[ "$DMG" == "$REPOSITORY_ROOT/dist/Live Church Translation.dmg" ]]
  rm -f "$DMG"
fi
hdiutil create \
  -volname "Live Church Translation" \
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
"$SCRIPT_DIR/audit_release_dmg.sh" "$DMG" "$IDENTITY"
echo "DMG bytes: $DMG_BYTES (limit: less than $MAX_RELEASE_ASSET_BYTES)"
echo "Created $DMG"

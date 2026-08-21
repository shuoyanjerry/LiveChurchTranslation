#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP="$REPOSITORY_ROOT/dist/LiveChurchTranslation.app"
DMG="$REPOSITORY_ROOT/dist/LiveChurchTranslation.dmg"
IDENTITY="${DEVELOPER_ID_APPLICATION:--}"

[[ -d "$APP" ]] || "$SCRIPT_DIR/package_release.sh"
STAGING="$(mktemp -d /tmp/live-church-dmg.XXXXXX)"
trap 'rm -rf "$STAGING"' EXIT
ditto "$APP" "$STAGING/LiveChurchTranslation.app"
ln -s /Applications "$STAGING/Applications"

if [[ -e "$DMG" ]]; then
  [[ "$DMG" == "$REPOSITORY_ROOT/dist/LiveChurchTranslation.dmg" ]]
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
echo "Created $DMG"

#!/bin/bash
set -euo pipefail

fail() {
  echo "Release DMG audit failed: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DMG="${1:-$REPOSITORY_ROOT/dist/Live Church Translation.dmg}"
IDENTITY="${2:-${DEVELOPER_ID_APPLICATION:--}}"
APP_NAME="Live Church Translation.app"
MOUNT_PARENT="$(mktemp -d /tmp/live-church-dmg-mount.XXXXXX)"
MOUNT_POINT="$MOUNT_PARENT/volume"
INSTALL_ROOT="$(mktemp -d /tmp/live-church-dmg-install.XXXXXX)"
ATTACHED=0

cleanup() {
  local status=$?
  if [[ "$ATTACHED" == "1" ]]; then
    if hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 \
      || hdiutil detach -force "$MOUNT_POINT" >/dev/null 2>&1; then
      ATTACHED=0
    else
      echo "Release DMG audit failed: the read-only image could not be detached" >&2
      status=1
    fi
  fi
  if [[ "$ATTACHED" == "0" && "$MOUNT_PARENT" == /tmp/live-church-dmg-mount.* ]]; then
    rm -rf "$MOUNT_PARENT" || status=1
  fi
  if [[ "$INSTALL_ROOT" == /tmp/live-church-dmg-install.* ]]; then
    rm -rf "$INSTALL_ROOT" || status=1
  fi
  exit "$status"
}
trap cleanup EXIT

[[ -f "$DMG" && ! -L "$DMG" && "$(basename "$DMG")" == "Live Church Translation.dmg" ]] \
  || fail "the expected ordinary DMG is missing"
hdiutil verify "$DMG" >/dev/null || fail "hdiutil rejected the DMG"

mkdir "$MOUNT_POINT"
hdiutil attach -readonly -nobrowse -noautoopen \
  -mountpoint "$MOUNT_POINT" "$DMG" >/dev/null \
  || fail "the DMG could not be mounted read-only"
ATTACHED=1

MOUNTED_APP="$MOUNT_POINT/$APP_NAME"
APPLICATIONS_LINK="$MOUNT_POINT/Applications"
[[ -d "$MOUNTED_APP" && ! -L "$MOUNTED_APP" ]] \
  || fail "the DMG does not contain the application at its root"
[[ -L "$APPLICATIONS_LINK" && "$(readlink "$APPLICATIONS_LINK")" == "/Applications" ]] \
  || fail "the DMG does not contain the required Applications shortcut"

UNEXPECTED="$({
  find "$MOUNT_POINT" -mindepth 1 -maxdepth 1 \
    ! -name "$APP_NAME" \
    ! -name Applications \
    ! -name .fseventsd \
    ! -name .metadata_never_index \
    ! -name .Trashes \
    -print
} || true)"
[[ -z "$UNEXPECTED" ]] || fail "the DMG contains an unexpected top-level item"

mkdir "$INSTALL_ROOT/Applications"
INSTALLED_APP="$INSTALL_ROOT/Applications/$APP_NAME"
ditto "$MOUNTED_APP" "$INSTALLED_APP"
[[ -d "$INSTALLED_APP" && ! -L "$INSTALLED_APP" ]] \
  || fail "drag-copy simulation did not create the application"
[[ -z "$(find "$INSTALLED_APP" -type l -print -quit)" ]] \
  || fail "the installed application contains a symbolic link"

"$SCRIPT_DIR/audit_release_app.sh" "$INSTALLED_APP" "$IDENTITY" >/dev/null
"$INSTALLED_APP/Contents/MacOS/LiveChurchTranslation" --verify-installation \
  || fail "the relocated application failed its non-interactive startup probe"
if [[ "$IDENTITY" != "-" ]]; then
  xcrun stapler validate "$INSTALLED_APP" >/dev/null \
    || fail "the relocated application has no valid notarization ticket"
  spctl --assess --type execute --verbose=4 "$INSTALLED_APP" >/dev/null \
    || fail "Gatekeeper rejected the relocated application"
fi

echo "Release DMG audit: PASS"
echo "Drag-copy destination: $INSTALLED_APP"

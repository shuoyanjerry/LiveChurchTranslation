#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SPEC="$REPOSITORY_ROOT/Packaging/XcodeGen/project.yml"
PROJECT="$REPOSITORY_ROOT/QuietLiturgyReader.xcodeproj"
XCODEGEN="$("$SCRIPT_DIR/fetch_xcodegen.sh")"

cd "$REPOSITORY_ROOT"
if [[ "${XCODE_PROJECT_SKIP_PACKAGE_RESOLVE:-0}" != "1" ]]; then
  swift package resolve
fi
"$XCODEGEN" --no-env --spec "$SPEC" \
  --project "$REPOSITORY_ROOT" --project-root "$REPOSITORY_ROOT"

RESOLVED_DIR="$PROJECT/project.xcworkspace/xcshareddata/swiftpm"
mkdir -p "$RESOLVED_DIR"
ditto "$REPOSITORY_ROOT/Package.resolved" "$RESOLVED_DIR/Package.resolved"
"$SCRIPT_DIR/check_xcode_project.sh" "$PROJECT"
echo "Generated $PROJECT with XcodeGen 2.45.4"

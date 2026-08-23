#!/bin/bash
set -euo pipefail

fail() {
  echo "Pinned runtime embedding failed: $*" >&2
  exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -n "${SRCROOT:-}" ]]; then
  REPOSITORY_ROOT="$(cd "$SRCROOT" && pwd)"
else
  REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi
[[ -f "$REPOSITORY_ROOT/Package.swift" ]] \
  || fail "SRCROOT does not identify the application repository"
RUNTIME="$REPOSITORY_ROOT/.artifacts/llama-b10549"
MODELS="$REPOSITORY_ROOT/.artifacts/release-models"
LICENSES="$REPOSITORY_ROOT/Packaging/Licenses"
MANIFEST="$REPOSITORY_ROOT/Packaging/LlamaRuntime.sha256"
HELPER_ENTITLEMENTS="$REPOSITORY_ROOT/Packaging/Helper.entitlements"
: "${TARGET_BUILD_DIR:?Xcode TARGET_BUILD_DIR is required}"
: "${CONTENTS_FOLDER_PATH:?Xcode CONTENTS_FOLDER_PATH is required}"
CONTENTS="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH"
EXECUTABLES="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

[[ -d "$RUNTIME" && ! -L "$RUNTIME" ]] \
  || fail "run Scripts/fetch_llama_runtime.sh before building the app target"
[[ -f "$MANIFEST" && -f "$HELPER_ENTITLEMENTS" ]] \
  || fail "runtime verification metadata is missing"
if ! (cd "$RUNTIME" && shasum -a 256 -c "$MANIFEST" >/dev/null); then
  fail "runtime file verification failed"
fi
"$REPOSITORY_ROOT/Scripts/check_release_models.sh" "$MODELS"
"$REPOSITORY_ROOT/Scripts/check_bundled_licenses.sh" "$LICENSES"

FILES=(
  llama-server
  libllama-server-impl.dylib
  libllama-common.0.dylib
  libmtmd.0.dylib
  libllama.0.dylib
  libggml.0.dylib
  libggml-cpu.0.dylib
  libggml-blas.0.dylib
  libggml-metal.0.dylib
  libggml-rpc.0.dylib
  libggml-base.0.dylib
)
for name in "${FILES[@]}"; do
  [[ -f "$RUNTIME/$name" && ! -L "$RUNTIME/$name" ]] \
    || fail "runtime member is missing or unsafe: $name"
done
file "$RUNTIME/llama-server" | grep -q 'arm64' \
  || fail "llama-server is not an arm64 executable"
otool -L "$RUNTIME/llama-server" | grep -q '@rpath/libllama-server-impl.dylib' \
  || fail "llama-server dependency layout is unexpected"

mkdir -p "$EXECUTABLES" "$RESOURCES"
for name in "${FILES[@]}"; do
  ditto "$RUNTIME/$name" "$EXECUTABLES/$name"
done
ditto "$RUNTIME/LICENSE" "$RESOURCES/llama.cpp-LICENSE"
ditto "$MODELS" "$RESOURCES/Models"
ditto "$LICENSES" "$RESOURCES/Licenses"
"$REPOSITORY_ROOT/Scripts/check_release_models.sh" "$RESOURCES/Models"
"$REPOSITORY_ROOT/Scripts/check_bundled_licenses.sh" "$RESOURCES/Licenses"
chmod 0755 "$EXECUTABLES/llama-server" "$EXECUTABLES"/*.dylib
chmod 0644 "$RESOURCES/llama.cpp-LICENSE" "$RESOURCES/Licenses"/*

if [[ "${CODE_SIGNING_ALLOWED:-YES}" != "YES" ]]; then
  [[ "${ACTION:-build}" != "install" ]] \
    || fail "archive action cannot disable nested-code signing"
  echo "Nested runtime copied without signing for a non-archive engineering build."
  exit 0
fi

IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY:--}"
if [[ "${ACTION:-build}" == "install" && "$IDENTITY" == "-" ]]; then
  fail "archive action requires a resolved Apple signing identity"
fi
SIGN_ARGS=(--force --sign "$IDENTITY" --generate-entitlement-der)
if [[ "${ENABLE_HARDENED_RUNTIME:-NO}" == "YES" && "$IDENTITY" != "-" ]]; then
  SIGN_ARGS+=(--options runtime)
fi
for library in "$EXECUTABLES"/*.dylib; do
  codesign "${SIGN_ARGS[@]}" "$library"
done
codesign "${SIGN_ARGS[@]}" --entitlements "$HELPER_ENTITLEMENTS" \
  "$EXECUTABLES/llama-server"
for code in "$EXECUTABLES"/*.dylib "$EXECUTABLES/llama-server"; do
  codesign --verify --strict --verbose=2 "$code"
done

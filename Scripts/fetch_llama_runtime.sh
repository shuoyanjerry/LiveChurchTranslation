#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${1:-$REPOSITORY_ROOT/.artifacts/llama-b10549}"
TAG="b10549"
ARCHIVE="llama-b10549-bin-macos-arm64.tar.gz"
URL="https://github.com/ggml-org/llama.cpp/releases/download/$TAG/$ARCHIVE"
EXPECTED_SHA="71e4b31afb020d6b71894eb8d1f2c0693038aec3f41f672f9fafb5055c8f2226"
MANIFEST="$REPOSITORY_ROOT/Packaging/LlamaRuntime.sha256"

verify_runtime() {
  [[ -d "$1" && ! -L "$1" && -x "$1/llama-server" ]] || return 1
  [[ -f "$1/.complete-$TAG" && ! -L "$1/.complete-$TAG" ]] || return 1
  [[ "$(tr -d '\n' <"$1/.complete-$TAG")" == "$EXPECTED_SHA" ]] || return 1
  (cd "$1" && shasum -a 256 -c "$MANIFEST" >/dev/null) || return 1
  otool -L "$1/llama-server" | grep -q '@rpath/libggml-metal.0.dylib' || return 1
  file "$1/llama-server" | grep -q 'arm64' || return 1
}

[[ -f "$MANIFEST" ]] || { echo "Runtime checksum manifest is missing" >&2; exit 1; }
if verify_runtime "$OUTPUT_DIR"; then
  exit 0
fi
if [[ -e "$OUTPUT_DIR" || -L "$OUTPUT_DIR" ]]; then
  echo "Existing runtime is incomplete or failed verification: $OUTPUT_DIR" >&2
  exit 1
fi

TEMP_DIR="$(mktemp -d /tmp/live-church-llama.XXXXXX)"
mkdir -p "$(dirname "$OUTPUT_DIR")"
STAGING_DIR="$(mktemp -d "$(dirname "$OUTPUT_DIR")/.llama-b10549.XXXXXX")"
cleanup() {
  rm -rf "$TEMP_DIR"
  if [[ -n "${STAGING_DIR:-}" && -d "$STAGING_DIR" ]]; then
    rm -rf "$STAGING_DIR"
  fi
}
trap cleanup EXIT
curl --fail --location --retry 3 --proto '=https' --tlsv1.2 \
  --output "$TEMP_DIR/$ARCHIVE" "$URL"

ACTUAL_SHA="$(shasum -a 256 "$TEMP_DIR/$ARCHIVE" | awk '{print $1}')"
if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
  echo "llama.cpp archive checksum mismatch" >&2
  exit 1
fi

tar -xzf "$TEMP_DIR/$ARCHIVE" -C "$TEMP_DIR"
SOURCE_DIR="$TEMP_DIR/llama-$TAG"

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
  LICENSE
)

for filename in "${FILES[@]}"; do
  install -m 0755 "$SOURCE_DIR/$filename" "$STAGING_DIR/$filename"
done
chmod 0644 "$STAGING_DIR/LICENSE"
printf '%s\n' "$EXPECTED_SHA" > "$STAGING_DIR/.complete-$TAG"

verify_runtime "$STAGING_DIR" || { echo "Installed runtime verification failed" >&2; exit 1; }
mv "$STAGING_DIR" "$OUTPUT_DIR"
STAGING_DIR=""

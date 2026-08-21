#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="${1:-$REPOSITORY_ROOT/.artifacts/llama-b10549}"
TAG="b10549"
ARCHIVE="llama-b10549-bin-macos-arm64.tar.gz"
URL="https://github.com/ggml-org/llama.cpp/releases/download/$TAG/$ARCHIVE"
EXPECTED_SHA="71e4b31afb020d6b71894eb8d1f2c0693038aec3f41f672f9fafb5055c8f2226"

if [[ -x "$OUTPUT_DIR/llama-server" && -f "$OUTPUT_DIR/.complete-$TAG" ]]; then
  exit 0
fi

TEMP_DIR="$(mktemp -d /tmp/live-church-llama.XXXXXX)"
trap 'rm -rf "$TEMP_DIR"' EXIT
curl --fail --location --retry 3 --output "$TEMP_DIR/$ARCHIVE" "$URL"

ACTUAL_SHA="$(shasum -a 256 "$TEMP_DIR/$ARCHIVE" | awk '{print $1}')"
if [[ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]]; then
  echo "llama.cpp archive checksum mismatch" >&2
  exit 1
fi

tar -xzf "$TEMP_DIR/$ARCHIVE" -C "$TEMP_DIR"
SOURCE_DIR="$TEMP_DIR/llama-$TAG"
mkdir -p "$OUTPUT_DIR"

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
  install -m 0755 "$SOURCE_DIR/$filename" "$OUTPUT_DIR/$filename"
done
chmod 0644 "$OUTPUT_DIR/LICENSE"
printf '%s\n' "$EXPECTED_SHA" > "$OUTPUT_DIR/.complete-$TAG"

otool -L "$OUTPUT_DIR/llama-server" | grep -q '@rpath/libggml-metal.0.dylib'
file "$OUTPUT_DIR/llama-server" | grep -q 'arm64'

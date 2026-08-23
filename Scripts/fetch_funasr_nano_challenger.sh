#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACT_ROOT="$PROJECT_ROOT/.artifacts/model-candidates/funasr-nano-int8-asset-394517157"
MODEL_NAME="sherpa-onnx-funasr-nano-int8-2025-12-30"
MODEL_DIR="$ARTIFACT_ROOT/$MODEL_NAME"
ARCHIVE="$ARTIFACT_ROOT/$MODEL_NAME.tar.bz2"
URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/$MODEL_NAME.tar.bz2"
ARCHIVE_BYTES=841730611
ARCHIVE_SHA="eb43d7ccc2e86b243f6a03b7df361033dda66db9523d1a92bf6aca2b50c9476b"

verify_file() {
    local path="$1"
    local expected_bytes="$2"
    local expected_sha="$3"
    [ -f "$path" ] || return 1
    [ "$(stat -f '%z' "$path")" = "$expected_bytes" ] || return 1
    [ "$(shasum -a 256 "$path" | awk '{print $1}')" = "$expected_sha" ]
}

verify_model() {
    local directory="$1"
    verify_file "$directory/encoder_adaptor.int8.onnx" 238277200 \
        d0246c823f2c34133ae0efee395d8a189c8f92643e3432f866939ee34d34492c || return 1
    verify_file "$directory/embedding.int8.onnx" 155583106 \
        a05d2816e284fcca29a5dccb2c14b9edeb638fd983a84cd4a447248889b6a408 || return 1
    verify_file "$directory/llm.int8.onnx" 600339316 \
        7f0c5a508b41474b1b1ec1cdbdefafd2cf8b3642c6915a0a425265b7b7d2c960 || return 1
    verify_file "$directory/Qwen3-0.6B/merges.txt" 1671853 \
        8831e4f1a044471340f7c0a83d7bd71306a5b867e95fd870f74d0c5308a904d5 || return 1
    verify_file "$directory/Qwen3-0.6B/tokenizer.json" 11422654 \
        aeb13307a71acd8fe81861d94ad54ab689df773318809eed3cbe794b4492dae4 || return 1
    verify_file "$directory/Qwen3-0.6B/vocab.json" 2776833 \
        ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910
}

mkdir -p "$ARTIFACT_ROOT"
if verify_model "$MODEL_DIR"; then
    echo "$MODEL_DIR"
    exit 0
fi

if ! verify_file "$ARCHIVE" "$ARCHIVE_BYTES" "$ARCHIVE_SHA"; then
    PARTIAL="$ARCHIVE.part"
    curl --fail --location --continue-at - --output "$PARTIAL" "$URL"
    verify_file "$PARTIAL" "$ARCHIVE_BYTES" "$ARCHIVE_SHA"
    mv "$PARTIAL" "$ARCHIVE"
fi

TEMP_DIR="$(mktemp -d "$ARTIFACT_ROOT/.extract.XXXXXX")"
trap 'rm -rf "$TEMP_DIR"' EXIT
tar -xjf "$ARCHIVE" -C "$TEMP_DIR"
verify_model "$TEMP_DIR/$MODEL_NAME"
if [ -e "$MODEL_DIR" ]; then
    echo "Existing challenger directory failed verification: $MODEL_DIR" >&2
    exit 1
fi
mv "$TEMP_DIR/$MODEL_NAME" "$MODEL_DIR"
echo "$MODEL_DIR"

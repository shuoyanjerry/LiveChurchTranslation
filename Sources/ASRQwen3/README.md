# ASRQwen3

## Purpose

Adapts the replaceable `ASRProvider` boundary to Qwen3-ASR INT8 through the
official sherpa-onnx Swift package. It performs sentence-level offline decoding
after VAD closes a segment; no network access occurs during inference.

## Public API

`Qwen3ASRProvider` and `Qwen3ASRConfiguration` are the only public types.
Per-request Mandarin language hints and comma-separated hotwords are attached to
an immutable sherpa stream.

## Dependencies

Depends only on `ASRAPI` and the pinned sherpa-onnx adapter. Callers never import
sherpa-onnx.

## Threading Model

The provider is an actor. It owns the native recognizer and serializes model
loading, decoding, and unloading.

## Failure Modes

Missing or corrupt artifacts fail model loading. Empty and sub-threshold audio
are rejected before decoding to guard against prompt-only hallucinations.

## Tests

Input and hotword guards are unit tested without loading model weights. Release
qualification additionally uses real sermon and silence fixtures on base M1.

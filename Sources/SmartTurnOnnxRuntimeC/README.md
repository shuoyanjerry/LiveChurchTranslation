# SmartTurnOnnxRuntimeC

## Purpose

Isolates the minimal ONNX Runtime C calls required by the optional Smart Turn
semantic-endpoint adapter. No domain or session target imports this module.

## Public API

`SmartTurnOnnxRuntimeC.h` exposes creation, one fixed-shape prediction,
destruction, error-message release, and runtime-version lookup. The surface is
deliberately model-specific rather than a general ONNX abstraction.

## Dependencies

Depends only on exact-pinned `OnnxRuntimeKit` 1.27.1. The package compiles this C
wrapper as C11 with warnings as errors. `-Wincomplete-umbrella` is suppressed only
for the upstream binary framework's incomplete umbrella declaration.

## Threading Model

Each opaque session has one actor owner in `SemanticEndpointSmartTurn`. A handle
must not be used concurrently or after destruction.

## Failure Modes

Every fallible operation returns a nonzero status and, when allocation permits,
an owned diagnostic string. Callers must release that string with
`st_ort_free_error`. Partial sessions are released on every construction failure.

## Tests

`SemanticEndpointSmartTurnTests` covers invalid lifecycle and input paths,
feature parity, model-integrity rejection, and an opt-in real ONNX probability
comparison against the official Python implementation.

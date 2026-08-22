# SemanticEndpointSmartTurn

Native macOS adapter for the quantized Pipecat Smart Turn v3.2 CPU model. The adapter owns ONNX
Runtime inside an actor and exposes only `SemanticEndpointAPI` values. It rejects non-16 kHz,
non-mono, empty, or non-finite input; model and inference failures are never converted into a
fallback decision.

## Pinned provenance

- Model: `pipecat-ai/smart-turn-v3`, revision
  `f766f81d3cfdf7737ac64aad813d91bbfd56bf93`
- File: `smart-turn-v3.2-cpu.onnx`
- SHA-256: `2bb026316b14a660486a75b1733cd3fbab8c2fd0314dc9af7be49f8cca967e4f`
- Runtime: `onnxruntime-libs` 1.27.1 through an isolated C bridge
- License: BSD-2-Clause; see `NOTICE`

`loadModel(at:)` verifies the digest before creating a CPU session. Session execution is sequential,
inter-op threads are set to one, and full graph optimization is enabled, matching the official
Python reference.

## Features and policy

Input is the full current turn. The adapter keeps its last eight seconds or left-pads it with zeros,
normalizes all 128,000 samples, and reproduces the Whisper 80-bin Slaney log-mel pipeline as a
`[1, 80, 800]` float tensor. The ONNX output is already a sigmoid completion probability.

The default threshold is 0.5 solely because that is the upstream reference default. It is not a
validated Chinese production threshold. Calibrate it on representative Mandarin sermons, and keep
VAD/time-limit safety policy outside this adapter before using the decision to close a live turn.

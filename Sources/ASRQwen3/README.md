# ASRQwen3

## Purpose

Adapts the replaceable `ASRProvider` boundary to Qwen3-ASR INT8 through the
official sherpa-onnx Swift package. It performs sentence-level offline decoding
after VAD closes a segment; no network access occurs during inference.

## Public API

`Qwen3ASRProvider` and `Qwen3ASRConfiguration` are the only public types.
Per-request Mandarin language hints and comma-separated hotwords are attached to
an immutable sherpa stream.

`ASRRequest.contextPrompt` is intentionally a **glossary-only** channel. Session
code supplies enabled source terminology, never prior utterances, guessed gender,
translation output, or an answer-shaped phrase. A held-out sermon experiment found
that those inputs did not repair an ambiguous *ta* and that prior-turn prose could
be echoed into recognition. Pronoun evidence is handled after ASR through the
replaceable discourse-resolution boundary.

## Dependencies

Depends on `ASRAPI`, the lightweight `ModelRuntimeAPI` health boundary, and the
pinned sherpa-onnx adapter. Callers never import sherpa-onnx.

## Threading Model

The provider is an actor. It owns the native recognizer and serializes model
loading, decoding, and unloading. The Apple Silicon default is four inference
threads. A frozen 220-segment qualification run produced identical hypotheses
at two, four, and six threads; four threads had the best overall latency/RTF
tradeoff on the qualified M1 Pro host. Callers can still inject a different
configuration for separately qualified hardware.
Loading the same standardized model location is idempotent while the recognizer
is resident. Its runtime health check reads only that actor-owned resident
state; it never reopens or hashes model artifacts.

## Failure Modes

Missing or corrupt artifacts fail model loading. Empty and sub-threshold audio
are rejected before decoding. Known nonspeech sentinels and a six-term minimum,
ordered hotword echo are rejected after decoding; when an echo prefixes real
speech, only the exact echo prefix is removed. A prompt-only first decode or a
pathological character or phrase loop triggers exactly one decode without
hotwords. A repeated failure is surfaced for durable retry and never enters the
transcript. The low-energy gate runs before either decode and is unchanged.

## Tests

Input and hotword guards are unit tested without loading model weights. Release
qualification additionally uses local real-sermon and silence fixtures. Media
with no redistribution permission stays outside the repository.

# ASRQwen3

## Purpose

Adapts the replaceable `ASRProvider` boundary to Qwen3-ASR INT8 through the
official sherpa-onnx Swift package. It performs sentence-level offline decoding
after VAD closes a segment; no network access occurs during inference.

## Public API

`Qwen3ASRProvider` and `Qwen3ASRConfiguration` are the only public types.
Per-request source-language hints and comma-separated hotwords are attached to an
immutable sherpa stream. Production requests currently select Mandarin or English.

`ASRRequest.contextPrompt` is intentionally a **glossary-only** channel in both directions. Session
code supplies enabled terminology for the selected source language, never prior utterances, guessed gender,
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
are rejected before decoding. A complete ordered hotword echo is detected for
prompts of every size; the established six-term threshold is retained for
truncated echoes from larger prompts. Prompt-only output, a suspected prompt
prefix, or a pathological character or phrase loop triggers exactly one decode
without hotwords. The provider uses a valid unprompted result instead of deleting
text from the prompted result, so genuine speech that starts with a glossary term
is preserved. A prefix fallback must remove the suspected echo without shortening
the compacted recognized body; otherwise the complete first result is kept.
The low-energy gate runs before either decode and is unchanged.

## Tests

Input and hotword guards are unit tested without loading model weights. Release
qualification additionally uses local real-sermon and silence fixtures. Media
with no redistribution permission stays outside the repository.

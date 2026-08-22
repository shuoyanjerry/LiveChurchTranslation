# TranslationHyMT2

## Purpose

Infrastructure adapter for faithful local Chinese-to-English translation with Tencent Hy-MT2 1.8B GGUF. It owns a bundled `llama-server` child process and talks only to its authenticated IPv4 loopback endpoint. The app user does not install llama.cpp or another runtime.

## Public API

- `HyMT2TranslationProvider`: `TranslationProvider` implementation. Call `loadModel(at:)`, then `translate(_:)`, and finally `shutdown()`.
- `HyMT2Configuration`: immutable helper, inference, timeout, and resource limits.
- `HyMT2Error`: explicit model, helper, startup, transport, and output-validation failures.

Each request may carry prior validator-approved `TranslationContextEntry` pairs. The prompt includes only the two newest pairs, labels them as non-output background, and keeps the current source in a separate delimiter. Callers remain responsible for admitting only finalized, persisted translations into this context.

`loadModel(at:)` accepts either a GGUF file or a directory containing `Hy-MT2-1.8B-Q4_K_M.gguf`.

## Dependencies

- `TranslationAPI` only for domain requests, results, terms, and the provider protocol.
- Foundation for `Process`, `URLSession`, JSON, clocks, and filesystem inspection.
- A pinned, signed `llama-server` executable must be copied into `Contents/Helpers` by release packaging. No llama.cpp symbols leak into the business layer.

## Threading Model

`HyMT2TranslationProvider`, the process controller, and the HTTP transport are actors. One provider serializes model lifecycle and inference. Cross-boundary inputs are immutable `Sendable` values; no singleton or shared mutable state is used.

## Failure Modes

Missing/non-executable helper, missing/ambiguous GGUF, launch failure, early helper termination, health timeout, HTTP error, malformed JSON, empty input, and rejected output are surfaced as errors. Output is rejected when it loses a selected glossary term, Arabic number, negation, or Scripture-reference shape; contains model commentary; or has implausible length. A validation rejection gets exactly one stricter retry.

The helper binds to `127.0.0.1` on a randomized high port with a per-launch random API key. Packaging must include the macOS network-client/server entitlements required by its sandbox policy.

## Tests

`TranslationHyMT2Tests` uses fake process and transport actors. It covers model lifecycle, readiness polling, exact single retry, glossary filtering, bounded background context, current-source delimiters, prompt rules, shutdown, termination, timeout, and each output guard without starting the real helper.

# SemanticEndpointAPI

Pure Swift, immutable, `Sendable` values and an async lifecycle protocol for semantic end-of-turn
analysis. Audio is represented explicitly as mono samples plus its sample rate and channel count;
adapters reject incompatible buffers instead of silently resampling or mixing them.

The result deliberately carries both the model probability and the configured decision threshold.
This keeps an adapter's probabilistic evidence available to callers without coupling the API to a
particular model runtime.

# ModelDownloadHTTP

## Purpose

`ModelDownloadHTTP` installs immutable local-model artifacts from HTTPS sources. It is
manifest-driven and contains no knowledge of Qwen, Hy-MT2, Hugging Face, or any other
specific model/vendor. The App composition root owns those choices and supplies fixed
revisions, byte counts, and SHA-256 values.

## Public API

- `ModelArtifactManifest`: one HTTPS artifact, safe relative path, exact size, and
  mandatory SHA-256.
- `ModelDownloadManifest`: descriptor, isolated installation directory, artifacts,
  and the URL shape returned to the caller (directory or one file).
- `ModelHTTPTransport`: injectable streaming/download boundary for URLSession or tests.
- `URLSessionModelHTTPTransport`: production transport using an ephemeral URLSession.
- `HTTPModelDownloader`: `ModelDownloadProvider` implementation with shared in-flight
  work and explicit cancellation.

## Dependencies

The module depends only on `ModelDownloadAPI`, `ModelRuntimeAPI`, Foundation, and
CryptoKit. Model vendors and inference SDKs are intentionally excluded.

## Threading Model

`HTTPModelDownloader` is an actor and owns the in-flight task registry. A model ID has
at most one installer task, while multiple callers await that same task. Artifact
hashing runs from async nonisolated work and checks cooperative cancellation between
1 MiB reads. Progress aggregation is a separate actor so URLSession delegate callbacks
cannot regress or publish state after completion.

## Failure Modes

- Non-HTTPS URLs, traversal paths, malformed checksums, duplicate IDs, and inconsistent
  descriptor sizes fail during configuration.
- Existing artifacts are trusted only after regular-file, exact-size, and SHA-256
  checks.
- Downloads land at `<artifact>.part`; only a verified file is atomically moved to its
  final path. Failed and cancelled transfers remove the partial file.
- Symlinked installation paths, unexpected directories, HTTP failures, size mismatch,
  and checksum mismatch fail closed and are reported through `ModelRuntimeReporting`.
- Completed valid files remain reusable if a later artifact in a multi-file model fails.

## Tests

`ModelDownloadHTTPTests` uses injected fake transports, location stores, and reporters.
It covers manifest validation, multi-file and single-file layouts, cache verification,
corrupt-file replacement, concurrent request deduplication, cancellation cleanup,
length mismatch, and symlink escape rejection. No test performs network I/O.

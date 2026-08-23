# Qwen3-ASR Manifest V2 Qualification — 2026-08-22

## Decision

Qwen3-ASR 0.6B INT8 remains the production Mandarin provider. The Apple
Silicon default is four inference threads. On the qualified M1 Pro host, four
threads produced exactly the same hypotheses as two and six threads while
giving the best overall latency, real-time factor, and three-second completion
tradeoff.

This is a component qualification, not a claim of perfect sermon recognition or
an end-to-end release certificate.

## Frozen input

The private, gitignored qualification manifest is:

```text
.artifacts/asr-qualification/public-domain-mandarin-scripture-v2.json
```

Its SHA-256 is
`8a485214b1c3fe01a931ec52bf14a59d409c3746b4e2e33dd28d0a80858302c8`.
It defines six public-domain Mandarin Scripture clips and 220 absolute,
half-open PCM ranges. Every range is bound to the source WAV and decoded Float32
payload by SHA-256. The shared loader re-read and re-hashed all 220 inputs before
the model comparison.

The previous corpus reports based on cumulative emitted VAD duration were
invalidated: those offsets were not absolute source-WAV timestamps and omitted
part of the source audio. None of their CER, latency, memory, or thread-ranking
numbers is used here.

## Results

All three current-code runs completed 220 of 220 attempts. Their status and
hypothesis payload SHA-256 was identical:

```text
58b19c508f976a02ee158d27852038bf4903a4dd073af52560193e0c977c4367
```

The edge-policy CER was `295 / 8160 = 3.615196%`; strict CER was
`813 / 8160 = 9.963235%`. Pronoun-confusion counts were also identical.

| Profile | p50 | p95 | Within 3 s | Decode | RTF |
| --- | ---: | ---: | ---: | ---: | ---: |
| 2 threads | 2.577 s | 3.534 s | 68.18% | 512.334 s | 0.19782 |
| **4 threads** | **2.005 s** | 3.177 s | **94.55%** | **409.204 s** | **0.15800** |
| 6 threads | 1.982 s | **3.159 s** | 92.73% | 413.277 s | 0.15957 |

Four threads improved p50 by about 22.2%, p95 by about 10.1%, and RTF by
about 20.1% relative to two threads, with no output change. Six threads gave
only a marginal p50/p95 improvement over four while reducing the three-second
success rate and increasing total decode time and RTF.

## Reproducibility and failure semantics

The harness requires the frozen Manifest V2, six exact production model
artifacts, six source WAVs, and six reference files. It verifies byte counts and
streaming SHA-256 before native model initialization. It rejects partial-clip,
prompt, decoder, or direct-thread overrides. Failures remain in all SLA
denominators and are persisted only as stable, redacted codes.

A first decode that consists only of the ASR hotword prompt, or a pathological
character/phrase loop, receives one retry without hotwords. Real speech prefixed
by an exact hotword echo is handled by the existing bounded prefix guard. A
second invalid result fails closed and is left for durable replay; it never
enters the transcript or translation context.

## Limits

- The corpus is Scripture speech, not a complete distribution of reverberant
  live sermons, music, congregational response, dialects, or code-switching.
- CER does not establish theological translation fidelity or correct Mandarin
  pronoun reference.
- The latency values are model-component measurements on one M1 Pro, not the
  full microphone-to-English pipeline on a base M1.
- A production release still requires the locked long-form sermon, noise/music,
  thermal, memory, device-switch, and end-to-end latency gates in
  [Testing.md](Testing.md).

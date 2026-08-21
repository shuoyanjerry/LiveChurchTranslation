# Release Qualification — 2026-08-21

## Build under test

- Product: Live Church Translation 1.0.0 (build 1)
- Host: Apple M1 Pro, 16 GB RAM, macOS 15.5
- Target: Apple Silicon (`arm64`), macOS 15.0 or later
- App bundle: 65 MB; DMG: 26 MB
- DMG SHA-256: `590d1f226cf6c034f058f3588742b89ba6f6892fa43a6250be2957b659d91c88`

## Automated gates

- Dependency graph: 46 targets, acyclic
- Architecture, 200-line, singleton, and cross-layer checks: passed
- SwiftFormat strict: passed
- SwiftLint 0.65.0 strict: 165 files, 0 violations
- Swift warnings-as-errors build: passed
- Swift Testing: 74 tests passed
- Deterministic dead-code check: passed
- App bundle strict code-signature verification: passed
- DMG integrity verification: passed
- Packaged application launch and graceful quit smoke test: passed

## Real-model qualification

The Mandarin fixture was 5.928625 seconds, mono, 16 kHz. Qwen3-ASR-0.6B INT8
decoded it in 1.147640 seconds. The raw output's observed homophone errors were
normalized before translation:

`休恩…因信生义…在圣灵里承受` → `救恩…因信称义…在圣灵里成圣`

Hy-MT2-1.8B Q4 translated four theological fixtures successfully:

| Fixture | Inference time |
| --- | ---: |
| Soteriology | 1.003365 s |
| Trinity and church practice | 0.609951 s |
| Ephesians 2:8 | 0.458180 s |
| Matthew 28:19 | 0.771472 s |

The fixtures cover salvation, grace, justification, justification by faith,
sanctification, regeneration, atonement, the Trinity, the Holy Spirit,
fellowship, ministry, the Lord's Supper, baptism, negation, and scripture
references. These are regression fixtures, not a claim of perfect translation.

## Distribution status

The generated app is ad-hoc signed because no Developer ID Application identity
or Apple notarization credentials are installed on this machine. Source and
packaging are release-ready, but a public Gatekeeper-trusted binary still requires
Developer ID signing, notarization, stapling, and clean-Mac acceptance testing.
The notarization script is `Scripts/notarize_release.sh`.

Base-M1 8 GB p95 latency, long-duration church audio, microphone permission on a
clean Mac, memory-pressure recovery, and multi-hour soak testing remain external
release gates; the measurements above must not be generalized to those cases.

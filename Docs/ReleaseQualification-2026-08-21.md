# Engineering Qualification Snapshot — 2026-08-21

This file records evidence observed during development of Quiet Liturgy Reader and the
final local engineering build below. It is not a production-release certificate; any
subsequent source change requires a rebuild and requalification before these artifact
results can be reused.

## Environment used for the recorded smoke

- Host: Apple M1 Pro, 16 GB RAM, macOS 15.5.
- Target: Apple Silicon (`arm64`), macOS 15.0 or later.
- ASR adapter: Qwen3-ASR 0.6B INT8 through sherpa-onnx.
- Translation adapter: Hy-MT2 1.8B Q4_K_M through the bundled llama.cpp helper.

This host is not a base M1 with 8 GB RAM.

## Synthetic Qwen3-ASR smoke

The supplied synthetic Mandarin fixture was 5.93 seconds, mono, 16 kHz. The final rerun
decoded it in 1.283 seconds, excluding model loading. The observed source and conservative
normalization were:

```text
raw:        救恩 … 因信生义 … 在圣灵里承受
normalized: 救恩 … 因信称义 … 在圣灵里承受
```

One reviewed literal correction was applied and audited in the final rerun:

- `因信生义` → `因信称义`

An earlier run of the same synthetic fixture produced `休恩` and exercised the separate
`休恩` → `救恩` rule. This observed variation is another reason not to infer corpus quality
from a single fixture.

`在圣灵里承受` was deliberately not rewritten to `在圣灵里成圣`; that substitution is
semantically ambiguous and would create a normalization hallucination. Consequently, this
smoke does **not** demonstrate correct recognition of 成圣 in that sentence. The raw text,
normalized text, and correction list remain available for review in the transcript model.

This is one synthetic-fixture smoke, not a Mandarin corpus result, WER/CER study, live
microphone test, long-sermon run, or latency percentile.

## Synthetic Hy-MT2 smoke

Four synthetic theological fixtures completed and passed the configured structural output
guards. An earlier per-fixture run ranged from 0.596 to 1.206 seconds, excluding model
loading. The latest real-model rerun ranged from 0.461 to 0.864 seconds for those four
fixtures; the five-case suite including one discourse-pronoun case completed in 4.483
seconds. The fixtures exercised soteriology, Trinity/church practice, Ephesians 2:8, and
Matthew 28:19 terminology and reference shapes.

## Offline Mandarin-sermon component replay

Four locally held public sermon recordings totaling 4 h 1 m 54 s were replayed through
the selected native libfvad/WebRTC hybrid and bounded endpoint policy. It produced 1,063
segments, including 29 under two seconds; 366 reached the 16.5-second hard cap and 288
closed at the preferred stable boundary. Frame-level parity against the pinned sibling
WebRTC implementation was exact across 725,722 windows. Six clips totaling 50 minutes were
decoded by the exact Qwen3-ASR INT8 stack in 603.197 seconds of decode time (RTF 0.2011).
The work also exposed prompt echoes on music/non-speech, added narrow rejection and
prefix-stripping guards, and qualified five reviewed discourse cases from three Mandarin
spiritual messages. A sixth reviewed object-pronoun case remains a documented abstention
gap. The Qwen clips used an earlier calibrated WebRTC segmentation baseline, so they
isolate ASR behavior rather than requalifying the final Swift boundaries.

This was not a continuous capture-to-reader run and had no aligned verbatim transcript or
human endpoint labels. Exact counts, Smart Turn shadow distributions, corpus provenance,
rights restrictions, and release gates are in
[the Mandarin discourse and endpoint report](MandarinDiscourseAndEndpointQualification-2026-08-21.md).

## Final local engineering gate and UI checks

- The final one-command quality gate passed: the 84-target dependency graph and
  architecture/cycle/source-length checks, strict SwiftFormat, SwiftLint with zero
  violations across 360 Swift files, warnings-as-errors build, 217 tests, and the
  deterministic dead-code check all succeeded.
- A real random-port `NWListener` was enabled from the Share UI, served the bundled reader
  over loopback with CSP/no-store/nosniff/frame/referrer/permissions headers, and stopped
  cleanly from the UI. No invitation credential was created during this manual check.
- The microphone request appeared with the correct usage description. The App displayed
  the distinct requesting-permission state, and Stop returned it to idle while the system
  prompt was pending. Accepting the system prompt was not automated.
- The ad-hoc Release App contains 70,891,586 logical bytes and occupies 70,934,528 bytes
  on disk. The verified DMG is 27,934,177 bytes with SHA-256
  `5f8a79ce188251ce3cf7011110ce7a3508910426dfc1a1e5a3943446eec5b561`.

Passing these fixtures means only that their outputs met the asserted expected terms and
guards. It does not establish general translation quality, absence of omissions or
hallucinations, naturalness across speakers, or a 1–3 second end-to-end service level.

## Evidence that must not be inferred

- The recorded 4-hour endpoint replay and 50-minute Qwen replay are component evidence,
  not a long-running end-to-end Qwen3-ASR/Hy-MT2 application qualification. Results from
  the sibling `church_translation` project remain design evidence only and are not
  transferable release evidence.
- The pinned native libfvad hybrid passed frame parity and unlabelled four-hour replay, but
  has not yet passed the required manually labelled 8-hour sermon boundary set.
- No base-M1 8 GB latency, memory-pressure, thermal, or multi-hour soak result is recorded.
- No clean-Mac accepted-microphone, device-switch, first-model-install, recovery, or
  multi-device Safari acceptance result is recorded here.
- No Developer ID signing, Apple notarization, stapling, or public GitHub publication is
  claimed here.

## Distribution status

Engineering packaging can use ad-hoc signing when Developer ID and notarization credentials
are unavailable. Such an artifact must remain labeled an engineering build. A public,
Gatekeeper-trusted release still requires a fresh full gate, fixed artifact hashes and
sizes, Developer ID signing, notarization, stapling, and clean-Mac acceptance evidence as
specified in [Testing](Testing.md).

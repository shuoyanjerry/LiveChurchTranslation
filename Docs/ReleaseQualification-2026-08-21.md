# Engineering Qualification Snapshot — 2026-08-21

This file records evidence observed during development of Quiet Liturgy Reader. It is not
a production-release certificate. The current repository must be rebuilt and requalified
after all source changes before artifact sizes, hashes, automated counts, or packaging
results are reported.

## Environment used for the recorded smoke

- Host: Apple M1 Pro, 16 GB RAM, macOS 15.5.
- Target: Apple Silicon (`arm64`), macOS 15.0 or later.
- ASR adapter: Qwen3-ASR 0.6B INT8 through sherpa-onnx.
- Translation adapter: Hy-MT2 1.8B Q4_K_M through the bundled llama.cpp helper.

This host is not a base M1 with 8 GB RAM.

## Synthetic Qwen3-ASR smoke

The supplied synthetic Mandarin fixture was 5.93 seconds, mono, 16 kHz. The final rerun
decoded it in 1.757 seconds, excluding model loading. The observed source and conservative normalization
were:

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
guards. The final per-fixture inference times ranged from 0.596 to 1.206 seconds, excluding model
loading. The fixtures exercised soteriology, Trinity/church practice, Ephesians 2:8, and
Matthew 28:19 terminology and reference shapes.

## Final local engineering gate and UI checks

- The complete local gate passed with 145 tests, warnings as errors, strict SwiftFormat,
  strict SwiftLint over 302 Swift files, architecture/cycle/200-line checks, and the
  deterministic dead-code scan.
- A real random-port `NWListener` was enabled from the Share UI, served the bundled reader
  over loopback with CSP/no-store/nosniff/frame/referrer/permissions headers, and stopped
  cleanly from the UI. No invitation credential was created during this manual check.
- The microphone request appeared with the correct usage description. The App displayed
  the distinct requesting-permission state, and Stop returned it to idle while the system
  prompt was pending. Accepting the system prompt was not automated.
- The ad-hoc Release App is 70,668,288 allocated bytes. The verified DMG is 27,845,285 bytes
  with SHA-256 `3f0a970d35648e89c3370d43948b00fa883f889859c418fda0a854f7abcdb2b2`.

Passing these fixtures means only that their outputs met the asserted expected terms and
guards. It does not establish general translation quality, absence of omissions or
hallucinations, naturalness across speakers, or a 1–3 second end-to-end service level.

## Evidence that must not be inferred

- No 94-minute or other long-sermon qualification has been run for this exact
  Qwen3-ASR/Hy-MT2 application stack. Results from the sibling `church_translation`
  project are design evidence only and are not transferable release evidence.
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

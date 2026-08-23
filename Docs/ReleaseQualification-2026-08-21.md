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

Fourteen locally held Mandarin spiritual-audio files totaling 27,524.215 seconds
(7.6456 hours) were replayed through the selected native libfvad/WebRTC hybrid and bounded
endpoint policy. It produced 2,321 segments, including 156 under two seconds; 584 reached
the 16.5-second hard-cap proxy, 480 closed at the preferred boundary, 461 at the soft
boundary, 791 after trailing silence, and 5 at end of stream. The retained-audio emission
lag proxy was 0.22 seconds at p50 and 0.68 seconds at p95. These are unlabelled structure
counts, not sentence-boundary accuracy. The set remains below the required 8 hours/12
sermons and has 0/84 planned human endpoint labels.

The final schema-v2 passive candidate-pause companion covered those 14 files,
27,524.215375 seconds, 2,321 unchanged production boundaries, and 4,596 pause episodes.
Threshold reaches were 4,596/4,044/2,954 at 250/300/400 ms. At 250 ms, 3,304 episodes
resolved as `speechResumed`; `segmentEnded` resolved 2 at end of stream, 38 at maximum
boundary, 461 at soft silence, and 791 at trailing silence. Two independent A/B artifacts
were byte-identical at SHA-256
`b7269f437ef9500329d02eb9bf63713a59e965a03addb05aa56617eed5aa45e5`.
Their source-bound provenance covers the exact 59-file production VAD set and exact 41-file
companion harness/validator/writer set, and independent red-team validation found zero
invariant failures.

These counts do not promote an endpoint: `speechResumed` is an acoustic continuation proxy,
not an unsafe human label. Final reason is the future production-segment outcome associated
with each episode, so its counts are episode-weighted rather than boundary totals. Frame
crossing and observation lag are not capture-to-reader end-to-end latency. Human
complete/incomplete and unsafe-cut labels remain mandatory before any threshold promotion.

The optional Smart Turn v3.2 experiment was removed on 2026-08-22. Its final 2,954-
candidate shadow had zero human labels and near-chance native-proxy separation
(`0.512348444` common-language ordering; fixed-threshold proxy balanced accuracy no higher
than `0.512780`). It never entered the App or changed a VAD decision. The adapter, runtime
bridge, model, dedicated qualification targets, reports, and unlabelled score-stratified
packet are no longer release inputs. A future semantic endpoint model must start from a
model-neutral, human-labelled corpus and may not reuse those proxy thresholds.

The deterministic blind packet currently contains 84 public-domain Scripture events and 0
human labels. Its packet aggregate, sealed provenance, and attestation SHA-256 values are
`389e19f71a080af50f320eaccb51f6fd0f8004da02cf9f395dc85290a6f04b39`,
`6e0990be715cc47ab57b36a481463a7b181b66dd67d3ba0346d63d30cce5950b`, and
`922d98c20fa121c67354a9fb055eb17a4034585f871d8bb75454a2a9211723df`.
It remains a generic public-Scripture boundary-workflow calibration packet and does not
count as the genuine-sermon release set.

A later media-only normalization now covers all 14 logical items in the local online-corpus
manifest without concatenating multi-track programs. It produced 128 independent 16 kHz
mono WAV tracks totaling 41,185.6485625 seconds (11.44046 hours), each with an explicit
reset and end-of-stream boundary. Only 8 logical items and 26,567.3133125 seconds
(7.37981 hours) are genuine church sermons; the remaining 6 items/120 tracks are scripted
or narrated spiritual programs. Therefore neither the 12-sermon nor the 8-hour genuine-
sermon gate is met. Its private replay manifest SHA-256 is
`2b5e75d3e497b08a946b64a44c7a364e98225c75fc59147ae5e31c81737548a6`.

The selected-WebRTC shadow baseline has now replayed all 128 v3 tracks. Its authoritative
A/B reports are
`.artifacts/v3-selected-vad/v3-selected-webrtc-exact-tree-{a,b}-2026-08-22.json`.
Each is 238,691 bytes and mode `0600` under a mode-`0700` directory; they are byte-identical
with SHA-256
`7060fcd3baed4d53e51fe64a3c1e677ff02a66e121fe402abbaafddda5b62ed8`.
All 128 attempts succeeded, 0 failed, and all 128 passed parity. Across 14 logical items,
658,970,377 PCM frames (41,185.6485625 seconds) produced 3,728 segments, including 193
under two seconds and 695 `.maximumDuration` proxies. Candidate reaches at 250/300/400 ms
were 7,742/6,970/5,383.

Only the genuine 8-sermon/8-track stratum counts toward release: 425,077,013 frames,
26,567.3133125 seconds (7.379809253 hours), and 2,225 segments. The 6-program/120-track
scripted or narrated stratum contains 233,893,364 frames, 14,618.33525 seconds
(4.060648681 hours), and 1,503 segments and never offsets the sermon gate. Independent
red-team review found zero P0/P1 findings; canonical encoding, privacy, provenance, and all
per-WAV joins passed. A P2 note records only a roughly 2–4e-12-second JSON `Double` tail in
two subgroup duration fields; authoritative duration is integer PCM frames divided by
16,000. The final-v1 A/B pair is non-authoritative because separate XCTest relinks drifted
its executable provenance. Final-v2 is superseded because package provenance changed; its
behavioral payload is byte-identical to this exact-tree pair.

This v3 report is shadow-only, has `decisionAuthority=none`, 0 human labels, and
`accuracyEligible=false`. Integrity is **GO**, but release is **NO-GO**: 8 < 12 sermons and
7.379809253 < 8 genuine hours. No semantic endpoint model is scheduled until a model-neutral
human-labelled gate exists.

The frozen public-domain Scripture Manifest V2 separately produced 220/220 Qwen attempts,
edge-free CER 3.6152%, strict CER 9.9632%, p50 2.005 seconds, p95 3.177 seconds, and
94.55% within three seconds. It misses the ≥98% final English latency gate and is not
sermon-domain CER. Prompt echoes on music/non-speech led to narrow rejection and
prefix-stripping guards; those guards do not establish a singing/music classifier.

This was not a continuous capture-to-reader run and had no aligned verbatim transcript or
human endpoint labels. Exact counts, corpus provenance, rights restrictions, and release
gates are in
[the Mandarin discourse and endpoint report](MandarinDiscourseAndEndpointQualification-2026-08-21.md).

The most recent frozen private Hy-MT schema-v2 diagnostic contains 144 attempts: 114 accepted and 30
failed closed, with 252 hard-check failures and 266 human-review requirements. It is bound
to the exact source/test/model/runtime/config/corpus snapshot and has report SHA-256
`f43aa47269fa544c15a75aa8f2b8bc5e0341578b42713b0d5fdb134ec5c4bc88`. The release-ready
gate fails. In particular, the safety-first resolver left 93 spoken-Mandarin pronouns
unresolved and made no silent male/deity inference, but recovered only 1/85 policy-labelled
resolvable occurrences. This is safe abstention with inadequate coverage, not complete
pronoun translation.

That diagnostic predates the latest VAD shadow-observation and persistent-postflight source
changes, so it is not evidence for the current working tree. The next quiescent exact-tree
run must use a new report filename and successfully create the non-overwriting mode-0600
postflight sidecar. Postflight establishes artifact/provenance integrity only; all quality
gates above must still pass independently.

## Final local engineering gate and UI checks

- The current one-command quality gate passed: the 94-target dependency graph and
  architecture/cycle/source-length checks, strict SwiftFormat, SwiftLint with zero
  violations across 809 Swift files, warnings-as-errors build, 665 tests, and the
  deterministic dead-code check all succeeded.
- A real random-port `NWListener` was enabled from the Share UI, served the bundled reader
  over loopback with CSP/no-store/nosniff/frame/referrer/permissions headers, and stopped
  cleanly from the UI. No invitation credential was created during this manual check.
- The microphone request appeared with the correct usage description. The App displayed
  the distinct requesting-permission state, and Stop returned it to idle while the system
  prompt was pending. Accepting the system prompt was not automated.
- The recorded ad-hoc App/DMG sizes and hashes predate the current 936-file source snapshot.
  They remain historical packaging diagnostics and are not current release artifacts. A
  fresh package, signature, notarization, stapling, and clean-Mac acceptance run is required.

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

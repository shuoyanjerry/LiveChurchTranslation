# Architecture

## Product boundary

Quiet Liturgy Reader has one primary pipeline:

```text
selected Chinese audio input
  → Mandarin speech segmentation and ASR
  → conservative, audited source correction
  → faithful English translation
  → durable transcript and continuous reader
```

It does not summarize, generate sermon content, mix audio, render worship slides, or
control external production software. Optional LAN sharing projects the same live reader;
the Mac remains the only inference host and transcript writer.

## Dependency rules

Dependencies point toward small contracts. `*API` targets contain protocols and immutable
`Sendable` values. Domain and feature implementations depend on those contracts, never on
concrete adapters. Infrastructure owns Apple frameworks, model SDKs, processes, files, and
network sockets. SwiftUI renders state and forwards intent. Only `ChurchTranslatorApp`
constructs concrete services.

```text
ChurchTranslatorApp (composition root)
  ├── LiveReader + UIDesignSystem
  ├── SessionManagement and remote feature implementations
  └── AVFoundation / model / filesystem / Network.framework adapters
                  │
                  ▼
           minimal *API contracts
                  ▲
                  │
          pure domain implementations
```

There are no service locators, mutable globals, feature-to-feature implementation imports,
or `Shared`, `Common`, and `Utils` targets. Cross-module mutation occurs only through
injected protocols. `Scripts/check_architecture.sh` and `ArchitectureCheck.swift` reject
cycles, forbidden layer edges, singleton access, garbage-drawer names, and Swift source
files over 200 lines.

## Module catalog

### Audio, language, and transcript pipeline

| Contract | Implementation | Responsibility |
| --- | --- | --- |
| `AudioCaptureAPI` | `AudioCaptureAVFoundation` | Input discovery, permission, and copied audio frames from the selected CoreAudio device |
| `AudioProcessingAPI` | `AudioProcessingCore` | Frame validation, downmixing, normalization, and streaming resampling |
| `VADAPI` | `VADCore`, `VADWebRTC`, `WebRTCVADC` | Replaceable classifier/boundary contracts, calibrated timing, pinned native libfvad sermon classifier, and AdaptiveEnergy fallback |
| `UtteranceRecoveryAPI` | `UtteranceRecoveryFileSystem` | Stage-before-inference records, restart replay, completion tombstones, limits, and quarantine |
| `ASRAPI` | `ASRQwen3`; qualification-only `ASRFunASRNano` | Replaceable ASR protocol, App-wired default Qwen3-ASR INT8 adapter with component qualification, and isolated Fun-ASR-Nano INT8 challenger |
| `ASRNormalizationAPI` | `ASRNormalizationCore` | Literal longest-match, non-cascading Mandarin corrections with full audit |
| `DiscourseResolutionAPI` | `DiscourseResolutionCore` | Pure-Swift current-turn explicit-evidence Mandarin pronoun repair, bounded two-turn safety/order context, limited prior-deity classification, typed abstention, and audit |
| `GlossaryAPI` | `GlossaryCore`, `GlossaryFileSystem` | Editable terminology, aliases, accepted targets, enforcement, validation, and atomic JSON storage |
| `TranslationAPI` | `TranslationHyMT2`, optional `TranslationApple` | Translation requests/results, two-entry context values, Hy-MT2 runtime and integrity guards |
| `TranscriptAPI` | `TranscriptCore` | Immutable raw/normalized/audited bilingual entries and actor-owned live buffer |
| `PersistenceAPI` | `PersistenceFileSystem` | Replaceable store and append-only JSONL/Markdown session adapter |

### Models, settings, and operations

| Contract | Implementation | Responsibility |
| --- | --- | --- |
| `ModelRuntimeAPI` | `ModelRuntimeCore` | Model identity, location, readiness, and actor-owned status reporting |
| `ModelDownloadAPI` | `ModelDownloadHTTP` | Revision-pinned HTTPS installation, in-flight byte caps, byte/hash verification, cancellation, and atomic promotion |
| `SettingsAPI` | `SettingsUserDefaults` | Immutable app settings and injected UserDefaults persistence |
| `LoggingAPI` | `LoggingOSLog` | Structured OSLog adapter with dynamic messages and metadata private by default |
| `DiagnosticsAPI` | `DiagnosticsCore` | Bounded diagnostic event recording and export |
| `SessionManagementAPI` | `SessionManagement` | Public state/events and the explicit live-session orchestration state machine |

### Optional LAN sharing

| Contract | Implementation | Responsibility |
| --- | --- | --- |
| `RemoteSharingAPI` | `RemoteProjectionCore` | Wire-safe projection values, authoritative revisions, bounded peer queues, and default-off switch |
| `RemotePairingAPI` | `RemotePairingCore` | Single-use invitations, hashed grants, roles, expiry, revocation, and redacted audit |
| `RemoteControlAPI` | `RemoteControlCore` | Closed control vocabulary, operator authorization, expected-revision checks, and replay-safe requests |
| — | `RemoteControlSessionAdapter` | Rejects remote Start without local recording consent and maps authorized Stop only |
| — | `RemoteProjectionSessionAdapter` | Maps session state and transcript deltas into a redacted remote projection |
| `RemoteDiscoveryAPI` | `RemoteDiscoveryBonjour` | Credential-free `_churchtranslate._tcp` service metadata |
| `RemoteTransportAPI` | `RemoteTransportNetwork` | Listener lifecycle plus bounded HTTP/WebSocket parsing, authorization, routing, heartbeats, and socket ownership |
| `RemoteWebAssetsAPI` | `RemoteWebAssets` | Allowlisted, dependency-free Safari reader assets |
| `RemoteSharingFeatureAPI` | `RemoteSharingFeature` | Default-off UI state, enable/disable, invitation creation, peers, and revocation |

### Presentation and composition

| Module | Responsibility |
| --- | --- |
| `UIDesignSystem` | Original semantic colors and controls; no official Northville logo, photography, or redistributed brand asset |
| `LiveReader` | Main-actor rendering and user-intent forwarding only; continuous reader and stable live-follow behavior |
| `ChurchTranslatorApp` | Directory creation and all dependency wiring; no business service or mutable feature state |

Each target README documents its public surface, dependencies, threading model, failures,
and focused tests.

## Ownership and concurrency

Audio frames, speech segments, recognition results, correction audits, translation
requests, transcript entries, and remote envelopes cross boundaries as values. Actors own
capture/model lifecycle, downloads, glossary mutation, transcript state, diagnostics,
session state, recovery storage, pairing, projection, transport, and remote commands.
AVFoundation callbacks copy samples before emitting a frame. SwiftUI-observable state is
main-actor isolated. No mutable reference is shared across a module boundary.

## Session state and durable data flow

```text
idle → preparing → listening ⇄ recognizing → translating → listening → stopping → idle
                         │                         │
                         └──── typed failure ─────┴───────────────→ failed
```

The sentence path is ordered deliberately:

1. Capture copies audio; processing emits normalized mono frames to the injected VAD. The
   production composition injects pinned libfvad mode 2 plus the measured strong-energy
   rescue. Short active segments use 950 ms silence, ordinary segments 650 ms, and retained
   active-segment age over 9 seconds may soft-split after 500 ms. From 15 seconds of retained
   age, including up to 240 ms pre-roll, the first stable 3-of-5 non-speech boundary closes
   the segment; 16.5 seconds is the hard cap. Two raw voiced frames cancel a pending endpoint.
   `AdaptiveEnergyClassifier` remains a functional fallback.
2. `UtteranceRecoveryStore.stage` durably commits the exact segment before inference.
3. Qwen3-ASR produces raw Mandarin. The normalizer applies only explicit aliases. The
   discourse resolver may repair narrowly eligible `他` / `她` spellings only from qualified
   current-turn evidence; prior human evidence may block or force abstention but never
   authorizes a later gender rewrite. A unique qualified prior deity anchor may classify an
   already-written `祂`, but only current-turn deity evidence may authorize a textual deity
   correction. Stable VAD source-segment identity, rather than dense UI ordinals, orders the
   bounded context. Both stages carry raw text plus every accepted change and its evidence
   into `TranscriptEntry`; ambiguity causes abstention, not a guess.
4. Hy-MT2 receives matched glossary terms and at most the latest two prior finalized,
   validator-approved, durably appended pairs. Context is marked as non-output background;
   only the separately delimited current source may be translated. Occurrence-level,
   request-nonce-bound proof blocks carry verified pronoun decisions through initial and
   strict-retry output. Fail-closed parsers reject missing, duplicated, forged, residual, or
   misbound protocol text. The prompt forbids gender inference from names, occupations, or
   stereotypes and permits singular `they` when evidence is absent. This mechanism reduces
   silent gender substitution; it does not make the still-failing translation corpus
   production-qualified.
5. Output guards withhold only empty output, exact source echo, explicit model refusal, and
   prompt/protocol leakage. Length, script, glossary, number, structurally detectable negation,
   Scripture-reference, and pronoun findings trigger one strict retry; a safe non-empty candidate
   is still returned in full with backend-only review codes. These checks are defect detectors,
   not substitutes for bilingual review.
6. Every safe entry is appended and synchronized before publication. Only entries without review
   findings enter the rolling translation context; review metadata is never rendered to readers.
7. The recovery record is marked complete. A crash before this step causes idempotent
   replay on the next preparation; unreadable artifacts move to quarantine and surface as
   recoverable issues.

No semantic endpoint model is linked into this live state transition. Candidate-pause traces
remain passive evidence only, and changing an offline experiment must not change session or UI
callers. The remaining labelled-corpus release gate is recorded in
[the qualification report](MandarinDiscourseAndEndpointQualification-2026-08-21.md).

Stop first prevents new capture, waits for capture callbacks, flushes VAD, drains staged
segments, and then finalizes the transcript. Typed finalization outcomes distinguish a
saved session, unresolved sentences, cancellation before capture, and save failure.

## LAN event flow and trust boundary

```text
Mac user enables Share
  → Network.framework listener + Bonjour advertisement
  → Mac issues one expiring viewer invitation
  → Safari redeems it and receives an HttpOnly role grant
  → snapshot barrier → bounded WebSocket deltas / resync
```

Security assumptions and limits are explicit:

- Sharing is disabled until the local Mac user enables it. Being on a private IP range is
  necessary for admission but never sufficient for authorization.
- Invitations are single-use and expire within five minutes. Grant credentials are
  high-entropy, stored as SHA-256 hashes, expire within 24 hours, and can be revoked
  individually or all at once. Disabling the listener revokes all grants.
- The invitation token is carried in a URL fragment, removed by the browser before normal
  requests, then exchanged for an HttpOnly, SameSite cookie. Tokens and transcript text
  are excluded from the bounded pairing audit.
- Host allowlisting and exact same-origin checks reduce DNS rebinding and cross-origin
  mutation. Queries, ambiguous/oversized requests, chunked bodies, malformed or unmasked
  WebSocket frames, non-local peers, and excess connections are rejected. Responses use
  CSP, `no-store`, `nosniff`, frame denial, no-referrer, and browser permission denial.
- This release issues viewer grants only. They can read the live transcript and translation
  but cannot control the meeting. The lower-level control boundary still rejects every remote
  Start request. No remote route exists for input selection, glossary, models, settings,
  history, export, shutdown, or arbitrary commands.
- The current listener is plain HTTP/WebSocket on the LAN. It does not protect transcript
  or credentials from a passive or active attacker who can observe or alter that network.
  The intended boundary is a trusted church/home LAN, not public Wi-Fi, a hostile VLAN, or
  Internet exposure. Do not port-forward the listener.

## Failure and replacement boundaries

Permission denial and input changes are capture failures; malformed frames and invalid VAD
configuration remain audio-boundary failures. Missing/corrupt models, cancelled downloads,
ASR failures, translation helper exit/timeout, output-integrity rejection, transcript I/O,
recovery quarantine, and LAN authorization/lifecycle failures remain typed at their owning
boundary. Failures are never silently converted into accepted transcript entries.

To replace capture, ASR, translation, transcript storage, recovery storage, or remote
transport, implement its API in a new adapter target, run contract tests, and change only
composition-root wiring. Business and UI callers do not change.

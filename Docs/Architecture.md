# Architecture

## Product boundary

Live Church Translation has separate live and imported-audio policies over shared speech
recognition infrastructure:

```text
selected microphone
  → language-scoped speech segmentation and ASR
  → Mandarin-only conservative source correction and discourse evidence, when applicable
  → faithful translation into English or Simplified Chinese
  → source-only durable transcript + bilingual continuous reader

imported audio
  → language-scoped speech segmentation and ASR
  → Mandarin-only conservative source correction and discourse evidence, when applicable
  → source-only durable transcript (no translation)
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
| `PersistenceAPI` | `PersistenceFileSystem` | Replaceable source-only JSONL/Markdown session adapter with legacy-content migration |
| `AudioImportAPI` | `AudioImportSessionAdapter` | Source-language transcription lifecycle, speech-only session policy, completion validation, and cancellation |

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
| `RemotePairingAPI` | `RemotePairingCore` | Session-lived reusable viewer links, bounded operator expiry, hashed grants, roles, revocation, and redacted audit |
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

The user-facing projection preserves these phases instead of collapsing them into a generic
“Live” or “Recording” state. The Mac and browser present quiet, persistent **Preparing**,
**Listening**, **Recognizing**, **Translating**, and **Finishing** feedback; the native terminal
label is **Incomplete** and the browser label is **Paused** when work cannot continue. Recording
duration is a separate fact. The browser also distinguishes Connecting, Connected, and
Reconnecting. A restrained activity indicator may accompany transient work, but progress is never
inserted into transcript text or presented as an unsolicited alert.

Passage time offsets are durable transcript data. Native and browser readers may hide their
timestamp rail independently; that presentation preference never removes or rewrites stored timing.

The speech-segment path is ordered deliberately:

1. Capture copies audio; processing emits normalized mono frames to the injected VAD. The
   production composition injects pinned libfvad mode 2 plus the measured strong-energy
   rescue. Short active segments use 950 ms silence, ordinary segments 650 ms, and retained
   active-segment age over 9 seconds may soft-split after 500 ms. From 15 seconds of retained
   age, including up to 240 ms pre-roll, the first stable 3-of-5 non-speech boundary closes
   the segment; 16.5 seconds is the hard cap. Two raw voiced frames cancel a pending endpoint.
   `AdaptiveEnergyClassifier` remains a functional fallback.
2. `UtteranceRecoveryStore.stage` durably commits the exact segment before inference.
3. Qwen3-ASR produces raw text in the selected source language. Mandarin input then passes
   through the literal alias normalizer and discourse resolver. The resolver may repair narrowly
   eligible `他` / `她` spellings only from qualified current-turn evidence; prior human evidence
   may block or force abstention but never authorizes a later gender rewrite. A unique qualified
   prior deity anchor may classify an already-written `祂`, but only current-turn deity evidence
   may authorize a textual deity correction. English input bypasses Mandarin spelling and pronoun
   correction. Stable VAD source-segment identity, rather than dense UI ordinals, orders the bounded
   context. Every path carries raw source text plus any accepted changes and their evidence into
   `TranscriptEntry`; ambiguity causes abstention, not a guess.
   The imported-audio policy proceeds directly from this recognition result to source persistence
   in step 6. It never prepares or invokes translation and never publishes a target-language value.
4. For live sessions, Hy-MT2 receives the complete recognized text for the current VAD segment in one
   request, matched glossary terms, and at most the latest two prior finalized,
   validator-approved pairs from the current process. Context is marked as non-output background;
   only the separately delimited current source may be translated. Occurrence-level,
   request-nonce-bound proof blocks carry verified pronoun decisions through initial and
   strict-retry output. Fail-closed parsers reject missing, duplicated, forged, residual, or
   misbound protocol text. The prompt forbids gender inference from names, occupations, or
   stereotypes and permits singular `they` when evidence is absent. This mechanism reduces
   silent gender substitution; it does not make the still-failing translation corpus
   production-qualified.
5. Live-translation output guards withhold only empty output, exact source echo, explicit model refusal, and
   prompt/protocol leakage. Length, script, glossary, number, structurally detectable negation,
   Scripture-reference, and pronoun findings trigger one strict retry; a safe non-empty candidate
   is still returned in full with backend-only review codes. These checks are defect detectors,
   not substitutes for bilingual review.
6. The source text, source audit, identity, order, and timing are synchronized to the source-only
   archive before the full in-memory entry is published to local and LAN readers. Translated text,
   translation review, and translation duration are never written to the session library. Only
   current-process entries without review findings enter rolling translation context.
7. The recovery record is marked complete. A crash before this step causes idempotent
   replay on the next preparation; unreadable artifacts move to quarantine and surface as
   recoverable issues.

No semantic endpoint model is linked into this live state transition. Candidate-pause traces
remain passive evidence only, and changing an offline experiment must not change session or UI
callers. The remaining labelled-corpus release gate is recorded in
[the qualification report](MandarinDiscourseAndEndpointQualification-2026-08-21.md).

Stop first prevents new capture, waits for capture callbacks, flushes VAD, drains staged
segments, and then finalizes the transcript. Typed finalization outcomes distinguish a
saved session, unresolved speech segments, cancellation before capture, and save failure.

## LAN event flow and trust boundary

```text
Mac user enables Share
  → Network.framework listener + Bonjour advertisement
  → Mac issues one session-lived reusable viewer invitation
  → Safari presents it and receives an HttpOnly session grant
  → snapshot barrier → bounded WebSocket deltas / resync
```

Security assumptions and limits are explicit:

- Sharing is disabled until the local Mac user enables it. Being on a private IP range is
  necessary for admission but never sufficient for authorization.
- Viewer invitations and grants are high-entropy, stored only as SHA-256 hashes, reusable by
  multiple listeners, and have the same in-memory lifetime as the active sharing session. The URL
  therefore remains valid until sharing is explicitly stopped or the app exits. Transient listener
  failure preserves the same invitation and grants. Disabling sharing or revoking everyone clears
  them atomically. The lower-level operator boundary retains single-use, five-minute invitations
  and 24-hour grants, but this release exposes no operator invitation route.
- The invitation token is carried in a URL fragment, removed by the browser before normal
  requests, then exchanged for an HttpOnly, SameSite cookie. Tokens and transcript text
  are excluded from the bounded pairing audit.
- Host allowlisting and exact same-origin checks reduce DNS rebinding and cross-origin
  mutation. Queries, ambiguous/oversized requests, chunked bodies, malformed or unmasked
  WebSocket frames, non-local peers, and excess connections are rejected. Responses use
  CSP, `no-store`, `nosniff`, frame denial, no-referrer, and browser permission denial.
- WebSocket parsing treats byte offsets as relative to `Data.startIndex`; a receive buffer may have
  a non-zero start index after an earlier frame is consumed. Every header, extended length, mask,
  and payload access must be bounds-checked before indexing. A supported single frame split across
  network receives remains buffered; WebSocket message fragmentation is unsupported. Malformed input
  closes only that peer, and no network byte sequence may trap the host process.
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

## 2026-08-24 LAN crash boundary

Two independent crash reports from the same macOS 15.5 engineering build, at 09:32:34 and
09:35:56 local time, ended in `Data._Representation.subscript.getter` from
`WebSocketFrameCodec.parseClientFrame(_:)`, called by
`NWRemoteConnectionHandler.processWebSocket(_:)`. The parser combined `Data.startIndex` for its
first bytes with zero-based integer offsets for later mask and payload access. Once a previously
consumed buffer no longer had a zero start index, a valid Safari frame could reach an out-of-bounds
subscript and terminate the whole app with `EXC_BREAKPOINT`.

This evidence invalidates the earlier inference from a successful one-request loopback smoke; it
does not invalidate that smoke's HTTP header observations. The correction is not qualified until
the exact final commit passes non-zero-index, receive-split, coalesced, extended-length, malformed,
heartbeat, and reconnect regressions, followed by repeated iPhone, iPad, and Mac Safari pairing and
stop/restart checks on a built application. Until then, LAN sharing remains a release blocker.

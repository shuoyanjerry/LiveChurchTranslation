# Production takeover — 2026-08-24

## Product contract

Live Church Translation is a macOS host application for Chinese-speaking churches. The Mac owns
capture, local inference, recording, transcript persistence, and LAN sharing. Listeners use a
phone, tablet, or computer browser to read the same live transcript and translation.

The supported directions are:

- Mandarin speech → Simplified Chinese transcript → faithful English translation;
- English speech → English transcript → faithful Simplified Chinese translation.

GitHub Releases is the only planned distribution channel for now. The code and packaging retain
App Store-grade sandbox, privacy, signing, and notarization discipline, but no App Store submission
is authorized. A green build is not permission to publish a Release.

## Engineering decisions

1. Offline processing remains the default. Qwen3-ASR and Hy-MT2 are revision- and hash-pinned;
   recordings and sermon text do not leave the Mac.
2. Capture truth precedes inference. The complete lossless recording and a durable segment ledger
   are the recovery authority when ASR or translation fails.
3. No silent omission is allowed. A persisted speech segment must end as translated, pending, or
   explicitly incomplete; it must never disappear as an apparent success.
4. “Spiritual” translation means faithful church register, not doctrinal invention. Negation,
   names, numbers, Scripture references, and reviewed terminology must be preserved. Ambiguous
   gender is not guessed.
5. Cloud providers may be evaluated later behind the existing provider contracts, but only as an
   explicit privacy/cost choice. They are not required for the offline product and are not a hidden
   fallback.
6. The Mac operator interface uses ordinary Chinese product language; the paired reader localizes fixed
   chrome to the selected target language. Model names, error codes, queues, transports, stack messages,
   and review metadata stay behind the presentation boundary.

## Verified baseline

The repository already provides continuous PCM16 CAF recording, crash-safe pre-inference staging,
JSONL and Markdown transcripts, a searchable session library, recording playback, bidirectional
mode selection, multi-format AVFoundation import, and token-protected LAN Safari reading.

The 2026-08-24 local quality run on commit `42db090` passed the 103-target architecture and
dependency checks, licensing, formatting, strict SwiftLint across 1,224 Swift files, a
warnings-as-errors build, static dead-code analysis, 17 notarization tests, 4 endpoint packet
tests, and 1,112 Swift tests. Full-Xcode-only project checks remain pending because this machine
currently exposes Command Line Tools rather than Xcode.

The real Hy-MT2 smoke lane on `42db090` passed four Mandarin-to-English theological fixtures,
three Mandarin-to-English pronoun fixtures, and twenty-four English-to-Simplified-Chinese theological
fixtures. The agreement-safe repair now renders an unresolved spoken Mandarin subject as singular
`they` only when the following verb form is provably number-invariant; it refuses unsafe repairs
such as `is`, `was`, `has`, `does`, and `continues`.

That smoke result is not a release qualification. The harder public per-occurrence pronoun matrix
passed 5 / 9 fixtures and failed 4 / 9. The failures involved four female ASR glyphs, mixed female
and male possessives, mixed male and female subjects, and mixed object/possessive occurrences.
They remain explicit release blockers rather than being converted into unreviewed output.

The real Hy-MT2 Q4 qualification bound to commit `fc973b6` replayed all 144 frozen bilingual
segments:

| Measure | Result |
| --- | ---: |
| Model execution successes | 144 / 144 |
| Model execution failures | 0 |
| Strict retries | 46 |
| Safety fallbacks | 0 |
| Median translation latency | 1.278 s |
| P95 translation latency | 4.958 s |
| Maximum translation latency | 9.103 s |
| Automated protection checks failed | 226 |
| Human-review-required checks | 382 |

The report and postflight hashes verify, but the automated quality gate is **NO-GO**. Execution
success proves coverage of model calls, not faithful translation. Independent bilingual and
theological adjudication remains required.

The sealed Simplified Chinese Scripture ASR lane is also **NO-GO**: 12 / 147 characters,
8.1633% CER, exceeded its frozen 8.0% ceiling. That sealed set must not be used for tuning; a new
blind partition is required. The 1.7B Qwen challenger was slower and did not consistently improve
critical church terms, so the selected 0.6B candidate remains the packaged default pending release
qualification.

The Qwen3-ASR 0.6B English synthetic compatibility lane was regenerated on `42db090` with
`languageCode=en`, 18 clips, 7 macOS voices, 6 locales, 68.748 seconds of audio, and 190 reference
words. It recorded 2 word edits (1.0526% WER), 6 character edits (0.5775% CER), and a 0.1626
real-time factor. The report SHA-256 is
`4ae250f4f8adb72bcee1fb107d89f10fe11000e5c6ed7d531749749edcc5b429`; its corpus manifest hash is
`f583a1b9f9af3b8cb4f68ed5218f1628caaca10ca302bdc87557f18fdd807568`. This proves synthetic
runtime and terminology compatibility only. One fixture transcribed “Prayer” as “Greer”, so real
English church speakers and acoustics remain mandatory before release.

## DMG relocation rehearsal

The 2026-08-24 engineering rehearsal built the complete self-contained Apple Silicon application,
including all seven pinned model artifacts, the pinned llama.cpp helper and ten dynamic libraries.
The quality gate passed 103 targets, strict lint across 1,225 Swift files, a warnings-as-errors
release build, 1,112 Swift tests, endpoint packet tests, notarization evidence tests, architecture,
licensing, formatting, and static dead-code checks.

Packaging removed the Swift build host's absolute runtime search path. The final app dependency
audit found only macOS system libraries and bundled `@rpath` dependencies resolved through
`@loader_path`. The new DMG audit then mounted the image read-only, verified the root application
and `/Applications` shortcut, copied the app into a fresh simulated Applications directory,
revalidated its signatures, resources, architecture, model inventory, license inventory, and
Mach-O dependency closure, and passed the relocated non-interactive startup probe.

The dry-run candidate is version/build `0.0.0 (24)`, 2,011,093,772 bytes, and SHA-256
`619dada46447e5f4d7098feaa7dcb2d22a0db2642220abc88b803ecd2601aea2`. It is an ad-hoc engineering
artifact built from a pre-commit working tree, not a distributable release. It proves that the
payload fits GitHub's 2 GiB asset ceiling and survives the local drag-copy rehearsal; it does not
prove Gatekeeper acceptance after download on another Mac. The supported installation target
remains Apple Silicon M1 or newer with macOS 15.0 or newer. Developer ID signing, notarization,
stapling, GitHub quarantine download, and the clean standard-user Mac matrix remain mandatory.

## Post-baseline LAN incident — 2026-08-24

The DMG rehearsal above did not pair a real Safari client or exercise a sequence of masked
WebSocket frames. Two later reports from that `0.0.0 (24)` engineering application on macOS 15.5
showed repeatable `EXC_BREAKPOINT` termination after LAN sharing was used. Both crashed in
`Data._Representation.subscript.getter` from `WebSocketFrameCodec.parseClientFrame(_:)`, reached
through `NWRemoteConnectionHandler.processWebSocket(_:)`.

The parser mixed offsets relative to the start of a frame with absolute `Data` indices. A buffer
whose first frame had already been consumed could have a non-zero `startIndex`; later mask and
payload subscripts then addressed the wrong index space and trapped the whole process. This is an
application defect, not an operating-system-update prerequisite. The earlier loopback listener
check remains useful HTTP/header evidence but is explicitly superseded as LAN stability evidence.
The rehearsal DMG must not be distributed.

The product correction also makes waiting legible without adding alarming pop-ups. Native and
browser readers preserve the processing sequence as small persistent states: Preparing, Listening,
Recognizing, Translating, and Finishing; an interrupted native session becomes Incomplete and the
browser becomes Paused. Sharing additionally distinguishes Connecting, Connected, and Reconnecting.
Recording duration is separate from the processing phase. Passage
timestamps remain recorded and visible by default but may be hidden independently in each reader;
hiding them never changes persisted timing.

The corrected tree passed the complete command-line gate on 2026-08-24, including non-zero `Data`
index, receive-split/coalesced frame, extended-length, malformed-frame, heartbeat, reconnect,
revocation, sharing stop/restart, progress-presentation, and timestamp-persistence automation.
Qualification remains **pending** for a full-Xcode build and repeated iPhone, iPad, and Mac Safari
cycles on that built app. Until those results are recorded, this incident remains a release blocker;
no previous packaging or loopback result transfers to the corrected tree.

## Release gates

A production claim requires current evidence on the exact protected commit:

- speech coverage at least 99.9% and critical short-word recall at least 99.5%;
- zero severe semantic omissions, additions, polarity reversals, or Scripture-reference changes;
- reviewed terminology compliance at least 99%, with every exception adjudicated;
- first readable subtitle P95 at most 1.2 s, ASR final P95 at most 2.5 s, and final translation P95
  at most 4.0 s on the supported base Mac;
- twenty independent three-hour meetings with zero recording frame loss and zero unrecoverable
  transcript gaps after stop, restart, and network interruption;
- real iPhone Safari, iPad Safari, and Mac browser acceptance on a trusted LAN;
- the 2026-08-24 WebSocket crash regression matrix, including repeated real-browser heartbeat,
  reconnect, and stop/restart cycles with zero host-process traps;
- WAV, AIFF, AAC, M4A, CAF, and a redistributable rights-safe MP3 fixture through the release
  import qualification;
- clean standard-user Mac install, launch, microphone permission, recording, import, sharing,
  removal, signed Developer ID, Apple notarization, Gatekeeper, and final DMG below GitHub's asset
  limit;
- root-governed freeze evidence and two independent qualified human reviewers.

Until all applicable gates pass, no version tag or GitHub Release may be created. Dry-run packaging
and draft pull requests are allowed; a draft prerelease is not a quality claim.

## Delivery order

1. Eliminate silent staged-segment loss and expose one-click re-transcription from the retained
   full recording without overwriting the original session.
2. Build a new blind Chinese Scripture ASR partition and an English church-speech qualification
   set; tune only on separate development partitions.
3. Complete independent Hy-MT2 review, then address omission, negation, pronoun, terminology, and
   latency failures in that order.
4. Run long-session recording, microphone hot-plug, memory, backpressure, crash, and restart soak
   tests on the minimum supported Mac.
5. Complete the physical browser/device matrix and decide whether trusted-LAN HTTP remains an
   explicitly accepted boundary or is replaced by authenticated TLS pairing.
6. Provision Developer ID/notary credentials, protected GitHub environment reviewers, release
   governance keys, SBOM/security automation, and clean-Mac acceptance evidence.
7. Build a signed/notarized draft candidate. Publish only after the exact-commit quality decision
   changes from NO-GO to GO.

## Primary references

- [Qwen3-ASR official repository](https://github.com/QwenLM/Qwen3-ASR)
- [Hy-MT official repository](https://github.com/Tencent-Hunyuan/Hy-MT2)
- [Hy-MT2 1.8B model card](https://huggingface.co/tencent/Hy-MT2-1.8B)
- [MQM translation error typology](https://themqm.org/error-types-2/typology/)
- [Apple notarization guidance](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [GitHub Releases guidance](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)

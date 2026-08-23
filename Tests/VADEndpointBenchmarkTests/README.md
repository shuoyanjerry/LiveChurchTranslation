# VADEndpointBenchmarkTests

## Purpose

Runs reproducible, opt-in endpoint-policy comparisons over private 16 kHz mono
sermon WAV files. No media, transcript, or generated report belongs in Git.

## Public API

This is a test-only executable surface. Set `SERMON_WAV_DIR` and
`VAD_BENCHMARK_OUTPUT`; optionally set `VAD_BENCHMARK_STRATEGIES` to a
comma-separated subset of `webrtcStable`, `webrtcPause500`,
`webrtcMode3Stable`, and `adaptiveEnergy`. The mode 3 strategy keeps the same
FSM and changes only libfvad aggressiveness for a structural challenger replay.

The report is model-neutral input for future offline challengers. Removing any optional
semantic model does not alter this target.

## Dependencies

Depends on the immutable audio/VAD APIs and the replaceable VAD implementations
under test. Production targets never depend on this benchmark.

## Threading Model

Each strategy/file pair owns one detector actor and is replayed serially. This
avoids cross-file adaptive state and makes per-file timing attribution explicit.

## Failure Modes

The run fails for missing WAVs, non-16 kHz/non-mono input, unknown strategy
names, hashing/read errors, or report-write errors. Partial final frames are sent
to the production state machine before flush.

## Tests

The benchmark emits per-file and aggregate JSON. `maximumDuration` count is a
structural hard-cap proxy, not a labeled unsafe-cut rate. Emission lag is measured after
retained audio, not from a human-annotated sentence boundary. No accuracy or SLA
claim is valid without locked manual boundary labels.

The current four-sermon snapshot emitted 1,064 segments for selected mode 2,
including 30 under two seconds and 366 hard-cap proxies. Mode 3 emitted 1,531,
including 150 under two seconds and 63 hard-cap proxies; that structural tradeoff
does not promote it. The expanded 7.6456-hour selected replay emitted 2,321
segments, 156 under two seconds, and 584 hard-cap proxies. Selected mode 2 remains
the default.

## Candidate-pause companion

`CandidatePauseBenchmarkTests` is a separate, strictly shadow-only replay over
the frozen 14-WAV, 27,524.215375-second selected snapshot. It accepts only the
source report with SHA-256
`1e08732048af648cf0e571c2aaccdc4722a943fb28fcb641f6d172df11cd32ff`.
Set `SERMON_WAV_DIR`, `VAD_CANDIDATE_PAUSE_SOURCE_REPORT`, and a fresh
`VAD_CANDIDATE_PAUSE_OUTPUT` below `.artifacts/vad-benchmarks`.

The companion constructs exactly `WebRTCVoiceActivityClassifier(.sermon)`
inside `CalibratedVoiceActivityDetector(.sermon)`; it has no adaptive-energy
fallback and runs no semantic endpoint, ASR, or translation model. Every 250/300/400 ms
checkpoint and resolution is joined by sequence to the finalized native
boundary. The report records only stable clip IDs, numeric timing, PCM/audio
hashes, configuration/source-report/implementation hashes, and aggregate
counts. It contains no filename, path, transcript, or private text.

Before writing, the harness requires exact WAV hashes, source boundary
signatures, event cardinalities, lifecycle ordering, joins, aggregates, and
unchanged inputs. Reports are deterministic JSON, created atomically with mode
`0600`, and never replace an existing file. A selected-lane parity test compares
all deterministic production voice-event fields and PCM hashes against the
shadow observation path. The independently generated segment UUID is excluded
from that signature because it is not an endpoint decision field.

The legacy source snapshot predates valid-sample EOF handling and the current
rule that excludes EOF from emission-lag percentiles. Reconciliation is allowed
only on the final `endOfStream` boundary: 1–319 provable padding samples and a
numeric-to-null EOF lag-policy change. Both are counted in the companion report;
all non-EOF fields remain exact-match gates. The frozen replay reconciled 826
padding samples across the corpus and five EOF lag fields.

The earlier schema-v1 companion pair is retained only as historical audit evidence. It
did not bind the companion validator/writer sources or the vendored WebRTC C sources, so
its implementation fingerprint is not sufficient for a current-code claim.

Two final schema-v2 replays produced byte-identical 19,784,041-byte reports with SHA-256
`b7269f437ef9500329d02eb9bf63713a59e965a03addb05aa56617eed5aa45e5`.
Their split implementation provenance binds 59 production files (AudioProcessingAPI,
VADAPI, VADCore, VADWebRTC, and all 21 compiled WebRTCVADC C/header files) and 41
companion/validator files. The validator also checks exact source/report/config/audio/PCM
digests, audio and boundary clocks, frame-aligned checkpoint deltas, episode lifecycle,
resolution joins, and rebuilt aggregates.

Each contains 4,596 pause episodes: 4,596/4,044/2,954 reached the 250/300/400 ms
checkpoints, respectively. There were 3,304 speech-resumed resolutions and
1,292 native segment-ended resolutions. Final-end-reason counts are
episode-weighted because more than one pause episode may join the same finalized
native segment; the separately reported finalized-boundary count remains 2,321.

Candidate-pause counts are observation coverage only. They are not boundary
accuracy, do not promote or veto a production endpoint, and cannot support a
release claim without locked independent human boundary labels. Replay runtime
is host/load dependent and descriptive, not an SLA measurement.

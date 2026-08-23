# SessionManagement

## Purpose

Orchestrates the live audio-to-transcript pipeline as an explicit session state
machine. It prepares models, captures and segments audio, recognizes and
normalizes and conservatively resolves Chinese, translates with glossary context, persists entries, replays
recoverable utterances, and drains work during stop.

## Public API

`LiveSessionCoordinator`, `LiveSessionDependencies`, `SessionModelDescriptors`,
and `InferenceModelPreparationCoordinator`. Concrete work is supplied entirely
through injected protocol implementations.

The ASR prompt is built only from enabled glossary source terms. Prior transcript
turns and pronoun/gender decisions never enter this channel. Finalized source/target
pairs are bounded translation background instead, while occurrence-level pronoun
evidence travels as immutable typed guidance.

One acoustic segment is recognized once, then Apple's sentence tokenizer divides
multi-sentence output without waiting for a later segment. Each sentence is
translated, persisted, and published in FIFO order before the next sentence starts.
Unpunctuated output remains one sentence and proceeds immediately. Split entries use
deterministic identities derived from the durable segment so crash recovery skips
already persisted sentences exactly once. This guarantee assumes the same staged
audio produces the same recognition and sentence topology; a model or normalizer
upgrade that changes that topology requires a versioned durable recognition-plan
migration before replay.

## Dependencies

Depends on the API targets for audio capture and processing, VAD, utterance
recovery, ASR and normalization, translation, glossary, model download and
runtime status, discourse resolution, transcripts and persistence, settings, logging, diagnostics,
and `SessionManagementAPI`. It has no UI or concrete infrastructure dependency.

## Threading Model

`LiveSessionCoordinator` is an actor. It owns the state machine, queues, child
tasks, stop/finalization ordering, and event publication. Cross-module values
are immutable and `Sendable`; injected services define their own isolation.
Model preparation is a separate actor with one shared in-flight attempt. A
cancelled session stops waiting without cancelling the application-level
download, and failed automatic preparation uses two bounded retries.
For live sessions, private recording and capture start before model preparation;
VAD segments are staged durably but inference workers remain closed until both
models are ready. Recovery replay excludes the current session so newly staged
speech is processed exactly once. Imported files retain model-first capture.
The live inference backlog is a constant-time ring buffer bounded to 32 staged
sentences and five minutes of 16 kHz PCM. If either limit is reached, or a
downstream sentence fails, the session switches to disk-recovery mode. Existing
and subsequent sentence artifacts remain durable for ordered replay on the next
start, while capture and the complete meeting recording continue independently.
If sentence staging itself fails, the bounded issue ledger points users to the
complete recording as the retry source instead of promising automatic replay.
Restart recovery requests four records at a time and releases each page before
loading the next, so a large disk backlog never reconstructs every PCM segment
in memory at once.

Imported files use a separate completeness policy. File decoding pauses at each
speech boundary until recognition, translation, transcript persistence, and
recovery acknowledgement finish. This keeps memory bounded without applying
the live backlog cutoff to an offline source. Any failed segment, non-durable
segment, cancellation, or early source termination makes the import explicitly
failed; it cannot be reported as a complete transcript.

## Failure Modes

Permission, preparation, capture, processing, recognition, translation,
persistence, recovery, and finalization failures become explicit session state
or `LiveSessionIssue` values. Pending utterances and unsaved transcripts are
retained when durable completion cannot be confirmed.
Segments deterministically classified as nonspeech or prompt-only output are
acknowledged without transcript publication so they do not replay forever.
Live and recovered discourse context is ordered only by `sourceSegmentSequence`;
the dense transcript presentation sequence is never evidence. Recovery excludes
future source segments even after filtered or failed gaps. Legacy entries without
a stable source identity remain readable but are conservatively omitted from
recovery translation and pronoun context.
Every live publication records a content-free sentence-tail-to-visible measurement.
The first completed capture frame anchors the audio timeline to a monotonic clock.
The realtime target is three seconds from each sentence's audio-tail estimate to
publication, including endpoint wait and inference; misses and invalid clock mappings
remain visible as warning diagnostics without changing transcript order.
Here, visibility ends at coordinator publication into the local UI and projection
consumer streams. It does not claim MainActor drawing, network delivery, or remote
device paint; those stages require their own downstream acknowledgement metrics.

## Tests

`SessionManagementTests` use protocol fakes to cover lifecycle transitions,
pipeline ordering, stop draining, shared model single-flight, cancellation,
retry, model failures, persistence failures, rolling context, recovery replay,
and event delivery.
Lifecycle tests prove capture-before-model behavior, durable pending audio after
model failure, current-session replay exclusion, and partial-recording preservation.
Queue tests cover FIFO wraparound, both admission limits, and an overload run
that proves every captured frame is recorded while a contiguous transcript tail
remains recoverable on disk.
Sentence tests cover bilingual semantic splitting, deterministic timing and identity,
ordered publication, the visibility SLA, unpunctuated long input, and partial
recovery without duplicate translation.
Import tests cover fast sources, inference and recovery-store failures, complete
recording retention, and early cancellation without false success.

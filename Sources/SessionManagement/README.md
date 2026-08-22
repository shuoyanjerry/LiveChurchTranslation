# SessionManagement

## Purpose

Orchestrates the live audio-to-transcript pipeline as an explicit session state
machine. It prepares models, captures and segments audio, recognizes and
normalizes and conservatively resolves Chinese, translates with glossary context, persists entries, replays
recoverable utterances, and drains work during stop.

## Public API

`LiveSessionCoordinator`, `LiveSessionDependencies`, and
`SessionModelDescriptors`. Concrete work is supplied entirely through injected
protocol implementations.

## Dependencies

Depends on the API targets for audio capture and processing, VAD, utterance
recovery, ASR and normalization, translation, glossary, model download and
runtime status, discourse resolution, transcripts and persistence, settings, logging, diagnostics,
and `SessionManagementAPI`. It has no UI or concrete infrastructure dependency.

## Threading Model

`LiveSessionCoordinator` is an actor. It owns the state machine, queues, child
tasks, stop/finalization ordering, and event publication. Cross-module values
are immutable and `Sendable`; injected services define their own isolation.

## Failure Modes

Permission, preparation, capture, processing, recognition, translation,
persistence, recovery, and finalization failures become explicit session state
or `LiveSessionIssue` values. Pending utterances and unsaved transcripts are
retained when durable completion cannot be confirmed.
Segments deterministically classified as nonspeech or prompt-only output are
acknowledged without transcript publication so they do not replay forever.

## Tests

`SessionManagementTests` use protocol fakes to cover lifecycle transitions,
pipeline ordering, stop draining, cancellation, model failures, persistence
failures, rolling context, recovery replay, and event delivery.

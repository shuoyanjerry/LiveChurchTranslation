# TranscriptAPI

## Purpose

Defines immutable transcript sessions, entries, source-correction audit values,
buffer events, and the replaceable live transcript-buffer boundary.

## Public API

`TranscriptEntry`, `TranscriptSession`, `TranscriptSourceCorrection`,
`TranscriptSourceAudit`, `TranscriptEvent`, `TranscriptBuffer`, and
`TranscriptBufferError`.

## Dependencies

`ASRAPI` for recognized utterances, `TranslationAPI` for translation results,
and Foundation for identifiers, dates, and coding.

## Threading Model

Transcript values, events, and the protocol are `Sendable`. Buffer mutation and
observation are asynchronous; implementations own state and stream delivery.

## Failure Modes

Entry construction without an active session is represented by
`TranscriptBufferError.noActiveSession`. Implementations define behavior for
nonthrowing append and finish calls when no session exists.

## Tests

`TranscriptCoreTests` exercises the concrete buffer through this API.
Persistence and session tests consume the immutable transcript values.

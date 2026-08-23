# TranscriptAPI

## Purpose

Defines immutable transcript sessions, entries, source-correction audit values,
buffer events, and the replaceable live transcript-buffer boundary.

## Public API

`TranscriptEntry`, `TranscriptSession`, `TranscriptSourceCorrection`,
`TranscriptSourceCorrectionKind`, `TranscriptSourcePronounDecision`,
`TranscriptSourceAudit`, `TranscriptEvent`, `TranscriptBuffer`, and
`TranscriptBufferError`. Pronoun decisions preserve the UTF-16 occurrence range
and unresolved, verified-human, or verified-deity evidence state without rewriting
ambiguous raw Chinese.

`TranscriptEntry.sequence` is the dense presentation order. The optional
`sourceSegmentSequence` is the stable VAD order within the containing session and
is the only transcript sequence permitted for discourse evidence. Old JSON without
that field remains decodable with an unknown source identity.

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
Legacy entry and correction JSON remains decodable when newer identity or structured
audit fields are absent.

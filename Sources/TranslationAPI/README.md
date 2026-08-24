# TranslationAPI

## Purpose

Stable, model-independent values and protocols for faithful source-to-target translation. This module contains no model runtime, persistence, session, or UI behavior.

## Public API

- `TranslationProvider`: replaceable asynchronous model boundary.
- `TranslationRequest` and `TranslationResult`: immutable request and result values.
- `TranslationTerm`: required or preferred terminology with semantic aliases and accepted targets.
- `TranslationContextEntry`: one finalized, validator-approved prior source/target pair.
  `TranslationRequest.context` defaults to empty for source compatibility.

Only finalized and persisted translations may be admitted to context by a session owner. A provider treats context as non-authoritative disambiguation background and must never translate it as current input.

## Dependencies

Foundation supplies `URL`, `UUID`, and localized errors. The API does not depend on Apple UI, audio, persistence, or a concrete model SDK.

## Threading Model

The provider protocol and every cross-boundary value are `Sendable`. Concrete providers define their own actor ownership and scheduling.

## Failure Modes

Typed provider errors cover unavailable runtimes, empty input, invalid model output, and explicit model failures. Implementations must surface failures and never silently fabricate a translation.

## Tests

Provider-adapter tests verify request compatibility, immutable context transport, glossary semantics, and result behavior using fake runtimes.

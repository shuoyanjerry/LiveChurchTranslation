# GlossaryAPI

## Purpose

Defines editable theological terminology independently of translation, storage, and UI implementations.

## Public API

`GlossaryEntry`, source/recognition aliases, accepted targets, `GlossaryEnforcement`, snapshots,
`GlossaryService`, `GlossaryRepository`, errors, and `DefaultGlossary`.

## Dependencies

Foundation only.

## Threading Model

Values are copyable and `Sendable`; repository and service methods are asynchronous.

## Failure Modes

The typed error vocabulary covers empty values, duplicates, alias conflicts, and persistence failure.

## Tests

`GlossaryCoreTests`, translation guard tests, and session tests cover the contract.

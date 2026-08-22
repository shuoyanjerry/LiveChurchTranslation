# GlossaryCore

## Purpose

Validates, orders, updates, restores, and snapshots the editable glossary through a repository protocol.

## Public API

`DefaultGlossaryService`, implementing `GlossaryService`.

## Dependencies

`GlossaryAPI` only.

## Threading Model

An actor owns the current revision and entries; callers receive immutable snapshots.

## Failure Modes

Invalid terms and conflicts fail before repository writes. Repository failures remain explicit.

## Tests

`GlossaryCoreTests` covers defaults, aliases, variants, enforcement, validation, updates, and restore.

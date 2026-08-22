# GlossaryFileSystem

## Purpose

Persists glossary entries as local JSON behind the replaceable repository boundary.

## Public API

`FileGlossaryRepository`, implementing `GlossaryRepository`.

## Dependencies

`GlossaryAPI` and Foundation.

## Threading Model

An actor serializes file reads and atomic writes.

## Failure Modes

Missing storage returns no saved glossary; decoding, directory, and write errors propagate.

## Tests

Glossary service tests use repository fakes; release integration verifies filesystem persistence.

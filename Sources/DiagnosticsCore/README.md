# DiagnosticsCore

## Purpose

Keeps a bounded in-memory diagnostic history, forwards structured records to an injected logger, and
exports JSON on request.

## Public API

`InMemoryDiagnosticsRecorder`, implementing `DiagnosticsRecorder`.

## Dependencies

`DiagnosticsAPI`, `LoggingAPI`, and Foundation.

## Threading Model

An actor owns the ring-like record collection and export lifecycle.

## Failure Modes

Capacity is clamped to at least one. Directory creation, encoding, and atomic export errors propagate.

## Tests

Session integration verifies recording calls; release checks verify diagnostic export and redaction.

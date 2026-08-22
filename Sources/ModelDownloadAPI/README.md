# ModelDownloadAPI

## Purpose

Defines the replaceable boundary that makes a versioned model available at a
local URL and supports cancellation.

## Public API

`ModelDownloadProvider` and `ModelDownloadError`.

## Dependencies

`ModelRuntimeAPI` for model identifiers and descriptors, plus Foundation for
URLs and localized errors.

## Threading Model

The provider protocol is `Sendable`, and download and cancellation operations
are asynchronous. Implementations own task synchronization and progress state.

## Failure Modes

Download failure, invalid or incomplete artifacts, and cancellation are
represented explicitly.

## Tests

`ModelDownloadHTTPTests` verifies the production downloader through this API.
Session tests use a fake provider.

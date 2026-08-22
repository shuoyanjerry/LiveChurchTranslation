# RemoteWebAssets

## Purpose

Provides the bundled Safari/iPhone/iPad projection client. No CDN, analytics, font, script, image, or other
network dependency is used.

## Public API

`RemoteWebAssetCatalog.asset(for:)` returns immutable bytes and MIME type for the three allowlisted paths.

## Dependencies

Foundation only.

## Threading Model

Assets are immutable static values. The browser client keeps its own view state on the browser main thread.

## Failure Modes

An unknown path returns `nil`. The client removes invitation credentials from the URL fragment before the
network request, relies on an HttpOnly grant cookie, reconnects with full jitter, requests an authoritative
snapshot after gaps, and closes stale connections after missed heartbeats.

## Tests

Catalog and security-header tests verify the allowlist, CSP-compatible external assets, and absence of
third-party URLs. Browser behavior preserves an upward-reading anchor and displays an unseen-entry count
until the user chooses Jump to Live.

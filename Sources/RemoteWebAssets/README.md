# RemoteWebAssets

## Purpose

Provides the bundled, read-only Safari/iPhone/iPad projection client. Its interface follows the session
target language: Mandarin-to-English sessions use English page chrome and `lang="en"`;
English-to-Simplified-Chinese sessions use Simplified Chinese chrome and `lang="zh-CN"`. No CDN,
analytics, font, script, image, or other network dependency is used.

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
Only fixed reader status copy is rendered; projection and browser transport messages are never shown. The
English phase vocabulary is Preparing, Listening, Recognizing, Translating, Finishing, and Paused, while
the Simplified Chinese page uses the matching `正在准备`, `正在聆听`, `正在识别`, `正在翻译`, `正在完成`,
and `已暂停`. Connecting, Connected, and Reconnecting remain separate connection states in each language.

Passage timestamps are visible by default. The browser may hide them with an independent
`readerTimestamps` `localStorage` preference; this changes the DOM presentation only and leaves projected
`startedMilliseconds` intact.

## Tests

Catalog and security-header tests verify the allowlist, CSP-compatible external assets, and absence of
third-party URLs. Source-contract assertions cover target-language chrome, document language, the
read-only production page, timestamp rendering, upward-reading anchor preservation, and unseen-entry
count. A mock DOM, WebSocket, clock, and `localStorage` execute the production handlers to prove
Connecting → Connected → latest phase ordering, Reconnecting, language switching, and the independent
timestamp preference.

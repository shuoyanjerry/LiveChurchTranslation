# RemoteTransportNetwork

## Purpose

Provides a zero-third-party, transport-facing HTTP/WebSocket security boundary: bounded parsers, strict
LAN/Host/Origin policy, shared cookie authorization, hardened responses, routing, socket bootstrap, and
per-connection session behavior.

## Public API

`NWRemoteTransportServer` implements `RemoteTransportServing`. Focused public test surfaces include
`RemoteServerComponents`, `HTTPRequestParser`, `RequestSecurityPolicy`, `RemoteHTTPRouter`,
`RemoteWebSocketGateway`, `RemoteSocketSession`, `WebSocketHandshake`, and `WebSocketFrameCodec`.

Endpoints are intentionally limited to bundled assets, `POST /api/pair`, `GET /api/snapshot`,
`POST /api/control`, and `GET /ws`. No route exists for shutdown, glossary, model, microphone, settings,
history, or export.

## Dependencies

`RemoteSharingAPI`, `RemoteControlAPI`, `RemotePairingAPI`, `RemoteDiscoveryAPI`,
`RemoteTransportAPI`, and `RemoteWebAssetsAPI`; Foundation, CryptoKit, and Network.framework. No
third-party server library is used.

## Threading Model

`NWRemoteTransportServer` owns the listener, connection registry, status streams, and heartbeat as an
actor. Per-connection actors parse and send independently. Pairing and projection dependencies own their
mutable state in separate actors. An absolute pre-authentication deadline releases silent or partial HTTP
clients; a successful WebSocket upgrade cancels that deadline. Connection admission enforces both a global
cap and a lower per-client cap so one LAN device cannot occupy every audience slot.

The listener intentionally accepts IPv4 only. Invitations use a Bonjour `.local` name, so browsers may
resolve both address families, but every successful pairing, snapshot, and WebSocket connection reaches the
same IPv4 identity. This avoids intermittent authorization failures without weakening client-bound grants.

## Failure Modes

Parsing rejects oversized, ambiguous, chunked, unmasked, or malformed input before routing. WebSocket
message fragmentation (`FIN = 0` or continuation opcodes) is unsupported and rejected, but an otherwise
valid single frame split across Network.framework receives is buffered until complete. Multiple complete
frames coalesced into one receive buffer are consumed in order.
All peers must be loopback, RFC1918, IPv4 link-local, IPv6 ULA, or IPv6 link-local. Host is an exact
allowlist match; mutations and WebSocket upgrades also require an exact same-origin match. HTTP and WS use
the same HttpOnly grant-cookie extractor. Grants are scoped to the normalized client address observed by the
server. WebSocket authorization is revalidated before the initial snapshot, every outbound drain, and every
inbound frame, so client-binding changes, grant revocation, and expiry fail closed. URLs with a query are
rejected, preventing token leakage.

Every response uses no-store, CSP, nosniff, no-referrer, frame-denial, and permission-denial headers.

Transient listener failure closes every socket but intentionally preserves in-memory viewer capabilities;
the sharing coordinator retries on the session's original port. Explicit sharing stop remains the
revocation boundary. The listener is plain HTTP/WebSocket and provides no confidentiality from a same-LAN
observer or active attacker. It is limited to explicitly enabled, paired use on a trusted LAN and must not
be port-forwarded. IPv6-only LANs are unsupported. Interface-change recovery and multi-device Safari
endurance remain release-qualification work.

Two macOS 15.5 crash reports from the `0.0.0 (24)` engineering app on 2026-08-24 supersede the earlier
loopback-only LAN-stability conclusion. Both trapped in `Data._Representation.subscript.getter` through
`WebSocketFrameCodec.parseClientFrame(_:)` and `NWRemoteConnectionHandler.processWebSocket(_:)`. The
parser had mixed indices relative to `Data.startIndex` with zero-based offsets after an earlier frame was
consumed. Frame parsing now uses one bounds-checked cursor relative to the current data view for the base
header, 16/64-bit extended length, mask, and payload. This implementation statement is not physical-device
qualification; repeated Safari heartbeat, reconnect, and stop/restart evidence remains required by
`Docs/Testing.md`.

## Tests

Tests cover request/header/body/frame bounds, origin and DNS-rebinding defenses, cookie parity, WebSocket
handshake rules, continuous grant authorization, silent/partial-client deadlines, viewer mutation denial,
secure response headers, and a real ephemeral localhost listener serving an asset plus snapshot/live
WebSocket data. Codec regressions cover non-zero-index data views, coalesced masked frames, extended-length
headers, and 16-bit frames truncated at every byte boundary. Lifetime tests distinguish transient failure
from explicit-stop revocation and session cookies from expiring operator cookies. These automated tests do
not replace the real-device matrix.

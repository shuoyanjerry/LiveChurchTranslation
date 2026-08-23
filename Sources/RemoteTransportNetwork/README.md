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
clients; a successful WebSocket upgrade cancels that deadline.

## Failure Modes

Parsing rejects oversized, ambiguous, chunked, fragmented, unmasked, or malformed input before routing.
All peers must be loopback, RFC1918, IPv4 link-local, IPv6 ULA, or IPv6 link-local. Host is an exact
allowlist match; mutations and WebSocket upgrades also require an exact same-origin match. HTTP and WS use
the same HttpOnly grant-cookie extractor. WebSocket authorization is revalidated before the initial
snapshot, every outbound drain, and every inbound frame, so grant revocation and expiry fail closed. URLs
with a query are rejected, preventing token leakage.

Every response uses no-store, CSP, nosniff, no-referrer, frame-denial, and permission-denial headers.

The listener is plain HTTP/WebSocket and provides no confidentiality from a same-LAN observer or active
attacker. It is limited to explicitly enabled, paired use on a trusted LAN and must not be port-forwarded.
Listener/interface-change recovery and multi-device Safari endurance remain release-qualification work.

## Tests

Tests cover request/header/body/frame bounds, origin and DNS-rebinding defenses, cookie parity, WebSocket
handshake rules, continuous grant authorization, silent/partial-client deadlines, viewer mutation denial,
secure response headers, and a real ephemeral localhost listener serving an asset plus snapshot/live
WebSocket data.

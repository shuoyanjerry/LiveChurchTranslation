# RemoteDiscoveryBonjour

## Purpose

Advertises an already-created local listener through Bonjour as `_churchtranslate._tcp`. Discovery exposes
only product/protocol metadata and the fact that pairing is required.

## Public API

`BonjourServiceDescriptor` and its pure `descriptor` value.

## Dependencies

`RemoteDiscoveryAPI` and Foundation. It does not depend on Network.framework, transport, pairing,
transcript, or UI modules.

## Threading Model

The immutable descriptor can be built anywhere. Listener ownership and callback queues remain with the
composition-provided transport adapter.

## Failure Modes

Bonjour discovery is advisory and may be unavailable due to local-network permission, interface changes,
or network policy. Callers must still offer a local address and must never weaken pairing when discovery
fails.

## Tests

Tests verify the fixed service type, bounded display name, deterministic TXT encoding, and absence of
credentials or transcript data.

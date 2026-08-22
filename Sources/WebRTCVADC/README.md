# WebRTCVADC

## Purpose

Isolates the unmodified libfvad C implementation used by `VADWebRTC`.

## Public API

Exports only upstream `fvad.h`. Swift callers outside the adapter module must
not import this target.

## Dependencies

None. The vendored source is pinned to commit
`532ab666c20d3cfda38bca63abbb0f152706c369`.
Its unchanged upstream files are the only source-length-check exemption; all
project-owned C, Swift, and web source remains subject to the 200-line gate.

## Threading Model

An `Fvad` allocation is mutable and not thread-safe. Its adapter supplies
single-owner lifetime and serialization.

## Failure Modes

Upstream reports allocation, invalid mode, invalid sample rate, and invalid
frame-size failures through its C return values. The Swift adapter normalizes
the initialization failures.

## Tests

The native implementation is exercised only through `VADWebRTCTests`, keeping
C details out of business-layer tests.

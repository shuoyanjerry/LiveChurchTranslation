# AudioCaptureAPI

## Purpose

Defines immutable audio/input values and the replaceable `AudioCaptureProvider`
boundary. It contains no AVFoundation or persistence implementation.

## Public API

`AudioCaptureProvider`, `AudioFrame`, `AudioInputID`, `AudioInputDevice`,
`AudioCaptureRequest`, `AudioCapturePermission`, and `AudioCaptureError`.

## Dependencies

Swift standard library plus Foundation only for localized error conformance.

## Threading model

All values are immutable and `Sendable`. Provider calls are asynchronous;
implementations define resource ownership and serialize state internally.

## Failure modes

Authorization denial, unavailable devices, invalid capture configuration, Core
Audio failures, and engine startup failures are explicit errors.

## Tests

Concrete provider adapters are tested by their implementation module. API fakes
can conform without importing Apple frameworks.

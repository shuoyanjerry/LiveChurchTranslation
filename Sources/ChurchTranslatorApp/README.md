# ChurchTranslatorApp

## Purpose

Acts only as the macOS composition root for Live Church Translation. Thin Swift Package and Xcode app
hosts delegate process startup to this library target.

## Public API

`LiveChurchTranslationApp` creates scenes through the internal `AppComposition` builder.
`InstallationProbe` exposes the noninteractive packaged-app verification used by the thin CLI host and
release audits; neither type exposes product business logic.

## Dependencies

Concrete production adapters and feature targets. Only process-host targets should depend on this
composition library.

## Threading Model

Composition and SwiftUI scene construction are main-actor isolated; injected actors retain their own
state ownership. Live capture and audio imports reuse one ASR actor and downloader through separate,
scope-specific model-preparation coordinators. Live capture additionally uses the shared translation
actor; imported audio follows the speech-only policy and never prepares or invokes translation for its
own processing.

## Failure Modes

Directory or dependency construction failure renders a bounded startup-failure view. Credentials and
signing configuration are never embedded here.

## Tests

Concrete behavior is tested at module boundaries; release qualification verifies the composed app.

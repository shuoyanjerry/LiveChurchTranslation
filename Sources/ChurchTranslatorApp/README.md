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
state ownership. Live capture and audio imports reuse one ASR actor, one
translation actor, one downloader, and one model-preparation coordinator so the
models occupy memory only once.

## Failure Modes

Directory or dependency construction failure renders a bounded startup-failure view. Credentials and
signing configuration are never embedded here.

## Tests

Concrete behavior is tested at module boundaries; release qualification verifies the composed app.

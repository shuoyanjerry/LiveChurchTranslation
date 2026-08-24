# ChurchTranslatorApp

## Purpose

Acts only as the macOS entry point and composition root for Live Church Translation.

## Public API

The executable exposes no reusable library API. `LiveChurchTranslationApp` creates scenes through
`AppComposition`.

## Dependencies

Concrete production adapters and feature targets. No other target may depend on this executable.

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

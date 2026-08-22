# TranslationApple

## Purpose

Provides an optional macOS 15 adapter from `TranslationProvider` to Apple's
on-device Translation framework, including glossary-marker protection and basic
output guards. The production composition currently selects `TranslationHyMT2`.

## Public API

`AppleTranslationProvider` and the SwiftUI
`View.appleTranslationRuntime(provider:)` modifier that attaches a
`TranslationSession`.

## Dependencies

The Swift Package target declares `TranslationAPI` and `ModelRuntimeAPI`. The
implementation also uses Foundation, SwiftUI, and Apple's Translation framework.

## Threading Model

The provider and runtime attachment are isolated to `MainActor`. Requests are
asynchronous, and the attached Translation session is owned by the provider.

## Failure Modes

An unattached runtime, preparation failure, empty source, translation failure,
unrestorable glossary markers, empty output, implausible output length, and
model-style commentary are surfaced as `TranslationProviderError` values.

## Tests

There is no dedicated `TranslationAppleTests` target. The active Hy-MT2 adapter
and shared translation contract are tested in `TranslationHyMT2Tests`.

# ChurchTranslatorCLI

## Purpose

Provides the thin Swift Package executable host for Live Church Translation. It contains no product
workflow or mutable service state; the `ChurchTranslatorApp` composition target owns the application.

## Public API

None. `LiveChurchTranslationMain` is the process entry point. The exact
`--verify-installation` argument runs the noninteractive bundled-installation probe and exits with a
success or failure status; every normal launch delegates to `LiveChurchTranslationApp.main()`.

## Dependencies

`ChurchTranslatorApp` plus Darwin process exit values.

## Threading Model

The entry point is main-actor isolated. Runtime concurrency is owned by services constructed in
`ChurchTranslatorApp`.

## Failure Modes

Installation-probe failure returns a nonzero process status. Normal startup construction failures are
rendered by the bounded startup-failure UI in `ChurchTranslatorApp`.

## Tests

Packaging audits exercise `--verify-installation` on relocated application bundles. Product behavior is
tested at the composed module boundaries rather than in a separate CLI test target.

# UI Design System

## Purpose

Provides the small semantic color and control vocabulary used by the macOS reader UI. The palette is Northville-inspired, but contains no official logo, photography, or redistributed brand assets.

## Public API

- `ChurchTheme`: semantic light-theme colors.
- `ChurchPrimaryButtonStyle` and `ChurchSecondaryButtonStyle`: accessible capsule controls.
- `GlassPanel`: restrained surface container.
- `StatusPill`: compact text-and-color status presentation.

## Dependencies

SwiftUI only. This target does not import feature, domain, persistence, audio, or model modules.

## Threading Model

All views render on SwiftUI's main actor. Values are immutable and no shared state is owned here.

## Failure Modes

The module performs no I/O. Invalid semantic use, such as using gold for body text, is prevented by convention and review.

## Tests

Feature snapshots and accessibility checks exercise these components through their consuming screens. Architecture checks enforce the dependency boundary and source-size limit.

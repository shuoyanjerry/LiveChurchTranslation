# Design QA — Quiet Liturgy Reader

## Artifacts and normalization

- Visual source of truth: `private working source capture`
- Source: 1487×1058 PNG; SHA-256 `4f38fbd0adb542c74f04b5842bc283eddf43895db5057c34de27e47d862c39f6`.
- Implementation screenshot: `.artifacts/design-qa/implementation-aligned.jpeg`.
- Implementation viewport: 1079×768 pixels, matching the source aspect ratio.
- Normalized images: `.artifacts/design-qa/source-normalized.png` and `.artifacts/design-qa/implementation-normalized.png`.
- Combined comparison input: `.artifacts/design-qa/comparison-full.png`.

The implementation screenshot uses a DEBUG-only transcript fixture. It renders the same
`LiveReader` production views used by the Release app; the fixture is excluded from Release
builds. Scrolling, live-follow suspension, and Jump to Live were exercised in the running
native app rather than simulated in the comparison image.

## Compared state

- Model presentation: local/on-device.
- Session: stopped, transcript retained, Start Translation available.
- Transcript: seven realistic English sermon passages.
- Chinese source: hidden.
- Viewport: user scrolled away from the live edge.
- Jump to Live: visible and then activated successfully.
- Overlays: none.

## Required fidelity surfaces

| Surface | Result | Evidence |
| --- | --- | --- |
| Typography | Pass | Large restrained serif transcript, small monospaced timestamps, and compact UI labels follow the selected direction. |
| Layout | Pass | A single continuous reader, aligned timestamp rail, quiet header, and bottom-right Jump to Live match the source hierarchy. |
| Color | Pass | Warm white/stone canvas, olive status, dark ink, and restrained gold accent are consistent with the selected Northville-inspired palette. |
| Assets | Pass with constraint | The official Northville mark is not redistributed; the app uses its original generated icon and an SF Symbol in-product. |
| Copy | Pass with product deviation | Generic sermon copy replaces church-specific schedule and identity copy because this is a reusable translation tool. |
| Controls | Pass | Input selection, Start/Stop, source visibility, Share, reader options, scroll pause, and Jump to Live are functional. |
| Accessibility | Pass | Named controls, 44-point targets, non-color status text, reduced-motion handling, and semantic Jump to Live behavior are present. |

## Findings and fixes

- `[P1 fixed]` The pre-redesign interface was a dark, card-based dashboard. It was replaced
  with the warm continuous reader shown in the current comparison.
- `[P1 fixed]` Content growth could be mistaken for user scrolling. Scroll intent is now
  tracked separately, and Jump to Live appears only after user-driven movement away from the
  live edge.
- `[P2 fixed]` Jump to Live initially reused the gold primary-button treatment. It now uses
  the white bordered secondary treatment visible in the selected source.
- `[P2 fixed]` The window and product title previously exposed the old Live Church
  Translation name. App chrome, bundle display name, and packaging now use Quiet Liturgy
  Reader.
- `[P2 accepted]` Share and reader options add controls absent from the source. They are
  required by the product scope and remain visually secondary.
- `[P2 accepted]` The official Northville logo, church name, schedule, and photography are
  intentionally absent because no redistribution license was supplied.
- `[P3 accepted]` The implementation uses a downward live-edge icon rather than the source's
  upward arrow because the newest transcript is below the reading position.

## Comparison history

### Pre-redesign baseline

- Evidence: `.artifacts/design/current-app-main.jpeg`.
- Result: failed visual direction—dark theme, empty state, card hierarchy, and old naming.
- Fix: rebuilt the feature as a warm, continuous reader with the selected typography,
  palette, toolbar hierarchy, and live-follow behavior.

### Pass 1

- Evidence: `.artifacts/design-qa/implementation-live-jump.jpeg`.
- Finding: reader hierarchy and transcript rhythm matched, but Jump to Live was too prominent.
- Fix: changed Jump to Live from the primary gold style to the bordered secondary style.

### Pass 2

- Evidence: `.artifacts/design-qa/comparison-full.png`.
- Result: no unresolved P0, P1, or unaccepted P2 visual defects. Remaining differences are
  explicit product, security, semantic, or asset-licensing decisions documented above.

## Interaction verification

- User scroll up preserved the historical reading position and exposed Jump to Live.
- Activating Jump to Live returned to the newest passage and removed the button.
- Local Reader remained off by default.
- Enabling Local Reader started a random-port Network.framework listener; a loopback request
  returned the bundled reader with CSP, no-store, permissions policy, referrer policy,
  frame-deny, and nosniff headers. Sharing was then stopped from the UI.

final result: passed

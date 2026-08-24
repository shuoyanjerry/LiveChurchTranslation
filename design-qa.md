# Design QA — Live Church Translation

## Current qualification status

Current visual and bundled-reader interaction status: **passed on 2026-08-24**. The built native app
shows quiet, persistent processing feedback, keeps recording duration separate, and independently
hides passage timestamps. Safari rendered the exact bundled HTML/CSS/JavaScript with a deterministic
transport fixture; it showed the translating phase in Simplified Chinese and removed only the visible
timestamps when its control was switched off.

Two real Safari crash reports on 2026-08-24 terminated the earlier `0.0.0 (24)` engineering app in
`WebSocketFrameCodec.parseClientFrame(_:)`. The parser correction and receive-split/coalesced-frame
regressions are implemented and automated, but the real-LAN Safari matrix in `Docs/Testing.md` still
requires full-Xcode and physical-device release qualification. This remaining engineering gate does
not change the visual result recorded here.

## Artifacts and normalization

- Shareable visual source: `Docs/Assets/design-qa-2026-08-24/source-transcript-crop.png`,
  1327×810 pixels; SHA-256
  `61f8db1099a0b2cc55bde6780db26d14bbeabdd1a04d4a4e3db0e207c7d76925`. The crop retains the
  typography, rhythm, timestamp rail, palette, and live-edge treatment used for comparison while
  excluding the unlicensed third-party identity header and mark from repository evidence.
- Native stopped implementation: `Docs/Assets/design-qa-2026-08-24/native-idle-timestamps.png`,
  900×652 pixels.
- Native translating implementation: `Docs/Assets/design-qa-2026-08-24/native-translating-recording.png`,
  900×652 pixels.
- Safari translating implementation: `Docs/Assets/design-qa-2026-08-24/safari-translating-top.jpeg`,
  1294×680 pixels. Repository screenshots contain the page viewport only; browser chrome and local
  filesystem paths are excluded.
- Hidden-timestamp evidence: `Docs/Assets/design-qa-2026-08-24/native-idle-timestamps-hidden.png`
  and `Docs/Assets/design-qa-2026-08-24/safari-translating-timestamps-hidden.jpeg`.
- Same-state source/native comparison input:
  `Docs/Assets/design-qa-2026-08-24/comparison-native-idle.png`, 2160×720 pixels, with both stopped
  transcript surfaces normalized into 1080×720 panels; SHA-256
  `0da75d5b05fe2b6cbce2b45349aaab4bbfc106e79fa0781c8d3b159705273dce`.
- Active native/Safari comparison input:
  `Docs/Assets/design-qa-2026-08-24/comparison-active-surfaces.png`, 2000×680 pixels, with both
  translating readers normalized into 1000×680 panels; SHA-256
  `fe0c0cb42baad674c91b98f864a1cfc69c02187c5cc5b95e071b772109b04c7b`.

The native implementation screenshots use a DEBUG-only transcript fixture. It renders the same
`LiveReader` production views used by the Release app; the fixture is excluded from Release
builds. The Safari page uses the production bundled assets; only `fetch` and `WebSocket` are replaced
by a local deterministic fixture. Scrolling, live-follow suspension, timestamp controls, and Jump to
Live were exercised in the running interfaces rather than inferred from screenshots.

## Compared states

- Same-state fidelity comparison: local/on-device, session stopped, transcript retained, English
  target passages, source hidden, scrolled away from the live edge, no overlays.
- Active cross-surface comparison: translating, timestamps visible, realistic bilingual sermon
  passages, native recording duration visible independently, no alert or transcript placeholder.
- Timestamp interaction comparison: identical content before and after the toggle; only the timestamp
  rail and its accessibility nodes are removed.

## Required fidelity surfaces

| Surface | Result | Evidence |
| --- | --- | --- |
| Typography | Pass | Large restrained serif transcript, small monospaced timestamps, and compact UI labels follow the selected direction. |
| Layout | Pass | A single continuous reader, aligned timestamp rail, quiet header, and bottom-right Jump to Live match the source hierarchy. |
| Color | Pass | Warm white/stone canvas, olive status, dark ink, and restrained gold accent are consistent with the selected reference palette. |
| Assets | Pass with constraint | The third-party reference mark is not redistributed; the app uses its original generated icon and an SF Symbol in-product. |
| Copy | Pass with product deviation | Generic sermon copy replaces church-specific schedule and identity copy because this is a reusable translation tool. |
| Controls | Pass | Input selection, Start/Stop, source visibility, Share, reader options, scroll pause, and Jump to Live are functional. |
| Accessibility | Pass | Named controls, 44-point targets, non-color status text, reduced-motion handling, and semantic Jump to Live behavior are present. |

The current results cover the progress treatment and timestamp controls in the native app and the
bundled Safari reader. They do not claim physical-LAN transport qualification.

## Findings and fixes

- `[P0 implemented — device verification pending]` The zero-origin `Data` indexing assumption in
  `WebSocketFrameCodec.parseClientFrame(_:)` was replaced with a relative bounds-checked cursor.
  Automated tests cover every receive split, a nonzero `Data.startIndex`, extended lengths,
  coalesced frames, non-minimal encodings, and oversized parser rejection. The handler maps
  `frameTooLarge` to close code 1009; a raw handler close-code assertion and repeated physical
  Safari regression remain release gates.
- `[P1 fixed]` Recording duration and processing phase are independent. Preparing, Listening,
  Recognizing, Translating, and Finishing use a small status pill with restrained progress motion;
  the browser has the matching bilingual phases without alerts or transcript placeholder text.
- `[P1 fixed]` Passage time offsets are visible by default and independently hideable on both
  readers. Hiding them leaves projected and durable JSONL/Markdown timing intact.
- `[P1 fixed]` The browser executes Connecting, holds Connected for at least 700 milliseconds, then
  presents the newest session phase; Reconnecting remains distinct. A mock DOM/WebSocket/clock test
  executes the production network handlers in both languages.
- `[P1 fixed]` The pre-redesign interface was a dark, card-based dashboard. It was replaced
  with the warm continuous reader shown in the current comparison.
- `[P1 fixed]` Content growth could be mistaken for user scrolling. Scroll intent is now
  tracked separately, and Jump to Live appears only after user-driven movement away from the
  live edge.
- `[P2 fixed]` Jump to Live initially reused the gold primary-button treatment. It now uses
  the white bordered secondary treatment visible in the selected source.
- `[P2 fixed]` An exploratory product label briefly diverged from the approved name. App
  chrome, bundle display name, and packaging now consistently use Live Church Translation.
- `[P2 accepted]` Share and reader options add controls absent from the source. They are
  required by the product scope and remain visually secondary.
- `[P2 accepted]` The third-party logo, organization name, schedule, and photography are
  intentionally absent because no redistribution license was supplied.
- `[P3 accepted]` The implementation uses a downward live-edge icon rather than the source's
  upward arrow because the newest transcript is below the reading position.

## Comparison history

### Pre-redesign baseline

- Evidence: private working capture, intentionally not retained in the repository.
- Result: failed visual direction—dark theme, empty state, card hierarchy, and old naming.
- Fix: rebuilt the feature as a warm, continuous reader with the selected typography,
  palette, toolbar hierarchy, and live-follow behavior.

### Pass 1

- Evidence: private working capture, intentionally not retained in the repository.
- Finding: reader hierarchy and transcript rhythm matched, but Jump to Live was too prominent.
- Fix: changed Jump to Live from the primary gold style to the bordered secondary style.

### Pass 2

- Evidence: `Docs/Assets/design-qa-2026-08-24/comparison-native-idle.png` and
  `Docs/Assets/design-qa-2026-08-24/comparison-active-surfaces.png`.
- Result: no unresolved P0, P1, or unaccepted P2 visual defects. Remaining differences are
  explicit product, security, semantic, or asset-licensing decisions documented above.

## Historical interaction verification

- User scroll up preserved the historical reading position and exposed Jump to Live.
- Activating Jump to Live returned to the newest passage and removed the button.
- Local Reader remained off by default.
- Enabling Local Reader started a random-port Network.framework listener; a loopback request
  returned the bundled reader with CSP, no-store, permissions policy, referrer policy,
  frame-deny, and nosniff headers. Sharing was then stopped from the UI.

That final bullet verifies one loopback HTTP exchange and a local stop action only. It did not pair
Safari or parse its WebSocket frame sequence and is superseded as LAN stability evidence by the two
crash reports.

Historical stopped-reader visual result: passed.
Current visual and bundled-reader interaction result: passed. Physical-LAN release result: pending.

final result: passed

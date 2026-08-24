# Mac App Store submission runbook

This runbook is the release source of truth for **Live Church Translation**. A green
Swift test run, an ad-hoc `.app`, a Developer ID `.dmg`, or a successful notarization
is not a Mac App Store build.

## Current delivery status

As observed on 2026-08-22, this checkout cannot truthfully produce an uploadable
archive:

- `xcode-select` points to Command Line Tools, not a full Xcode installation.
- the login keychain contains no valid code-signing identities;
- no Apple Developer team, distribution profile, App Store Connect record, public
  privacy-policy URL, or App Store Connect credentials are available to this checkout.

The repository now contains a genuine macOS Application target in
`LiveChurchTranslation.xcodeproj`, a shared `LiveChurchTranslation` Archive scheme, and a
repository-local Swift package dependency on the production `ChurchTranslatorApp`
library. Static structure, plist, scheme, dependency-lock, entitlement, privacy,
runtime-manifest, and deterministic-generation checks pass. An actual Xcode build,
Archive, export, Organizer validation, and upload remain unverified until the missing
Apple tooling and account-controlled signing material are supplied.

`Scripts/archive_app_store.sh` fails before archive creation when any of these build
preconditions is absent. It does not manufacture an `.xcarchive` around an unsigned
SwiftPM executable. `Scripts/export_app_store.sh` accepts only an audited archive and
never uploads it.

## Apple references

- [App Sandbox is mandatory for Mac App Store distribution](https://developer.apple.com/documentation/security/app-sandbox).
- [Configure the macOS App Sandbox capabilities](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox).
- [Embed a sandboxed command-line helper](https://developer.apple.com/documentation/xcode/embedding-a-helper-tool-in-a-sandboxed-app).
- [Understand macOS provisioning-profile requirements](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles).
- [Place a macOS privacy manifest in `Contents/Resources`](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk).
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/),
  including explicit consent and a clear recording indication in 2.5.14.
- [Upload builds with Xcode or Transporter](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds).

Recheck these pages and Xcode's generated privacy report for every release; Apple
requirements and accepted export-option keys change over time.

## Tracked Xcode application target

`Packaging/XcodeGen/project.yml` is the reviewable source of truth for the generated
project. `Scripts/fetch_xcodegen.sh` bootstraps only XcodeGen 2.45.4 from its HTTPS
release URL, verifies the pinned archive and executable SHA-256 values before running
the executable, and installs it only under the repository's ignored `.artifacts`
directory. It does not use or modify a system installation. Regenerate and audit the
tracked project with:

```sh
./Scripts/generate_xcode_project.sh
./Scripts/check_xcode_project.sh
```

For a disconnected reproducibility check after the verified cache and
`Package.resolved` already exist:

```sh
XCODEGEN_OFFLINE=1 XCODE_PROJECT_SKIP_PACKAGE_RESOLVE=1 \
./Scripts/generate_xcode_project.sh
```

Review and commit both `Packaging/XcodeGen/project.yml` and the resulting
`LiveChurchTranslation.xcodeproj`. Never hand-edit the generated `project.pbxproj`.
The target compiles the thin App host, which delegates to the production composition
root in the local Swift package, and satisfies this contract:

| Target setting/artifact | Required value |
| --- | --- |
| Product type | `com.apple.product-type.application` |
| Bundle ID | `com.shuoyan.LiveChurchTranslation` |
| Minimum system | macOS 15.0 |
| Info plist | `Packaging/Info.plist` |
| Main entitlements | `Packaging/LiveChurchTranslation.entitlements` |
| Privacy manifest | copied to `Contents/Resources/PrivacyInfo.xcprivacy` |
| Translation helper | executable at `Contents/MacOS/llama-server` |
| Helper entitlements | exactly App Sandbox plus inheritance from `Packaging/Helper.entitlements` |
| llama.cpp libraries | copied beside the helper and signed as nested code |
| Third-party licenses | verified files copied to `Contents/Resources/Licenses` |
| App icon | compiled `AppIcon` from `Assets/AppIcon.xcassets/AppIcon.appiconset` |
| Install behavior | macOS Application target; archive under `Products/Applications` |

The target's declared-input/output post-build phase runs
`Scripts/embed_app_store_runtime.sh`. It copies the pinned helper and dynamic
libraries into `Contents/MacOS`, copies the verified model/runtime dependency licenses into
Resources, signs each nested binary with the expanded build identity, and applies only
`Packaging/Helper.entitlements` to the helper. Xcode signs the main app last. The
phase refuses an Archive action with a missing or ad-hoc identity. Do not move the
helper to the legacy `Contents/Helpers` path, give it independent
network/file/microphone entitlements, or download executable code after installation.

The helper archive and every installed member are revision- and SHA-256-pinned by
`Scripts/fetch_llama_runtime.sh` and `Packaging/LlamaRuntime.sha256`. The archive
script verifies the runtime before invoking Xcode. A direct Xcode build intentionally
fails with an actionable message when the verified runtime is absent; run the fetch
script first rather than weakening the build phase.

## Entitlement justification

The app uses only the following sandbox surface:

| Entitlement | User-visible need |
| --- | --- |
| `com.apple.security.app-sandbox` | Required containment for a Mac App Store app. |
| `com.apple.security.device.microphone` | Live speech recognition and user-confirmed meeting recording. |
| `com.apple.security.device.audio-input` | Audio-input compatibility for the current capture stack; validate it against the shipping SDK before each submission. |
| `com.apple.security.network.client` | Authenticated loopback calls to the local translation helper; debug source builds may also use the pinned model installer. |
| `com.apple.security.network.server` | Opt-in Bonjour HTTP/WebSocket reader for explicitly paired LAN devices. |
| `com.apple.security.files.user-selected.read-only` | Immediate read-only transcription of audio selected in the system file picker. |

Do not add broad Downloads, Documents, home-directory, automation, or temporary
exception entitlements. The `llama-server` child has exactly
`com.apple.security.app-sandbox=true` and `com.apple.security.inherit=true`, as Apple
requires for sandbox inheritance.

## Archive and export

Prerequisites:

1. Install a supported full Xcode and select it with `sudo xcode-select -s`.
2. Add the Bundle ID and macOS app to the correct Apple Developer/App Store Connect
   team.
3. Install an Apple Distribution identity with its private key. Prefer automatic
   signing. A macOS app using only App Sandbox and Hardened Runtime entitlements may
   not need an embedded provisioning profile; install a matching Mac App Store
   profile if Xcode requires one or a restricted entitlement is added. Manual export
   also requires the appropriate installer distribution identity.
4. Regenerate the project and confirm `Scripts/check_xcode_project.sh` passes. With
   full Xcode selected, the check additionally requires Xcode to discover the app
   target and shared scheme.
5. Run the full clean-Mac, model, audio, UI, accessibility, LAN, and privacy release
   qualification. Do not use these packaging scripts as product-quality evidence.

Automatic signing example:

```sh
APP_STORE_TEAM_ID=ABCDEFGHIJ \
APP_VERSION=1.0.0 \
APP_BUILD_NUMBER=1 \
./Scripts/archive_app_store.sh

APP_STORE_TEAM_ID=ABCDEFGHIJ \
./Scripts/export_app_store.sh
```

The archive script defaults to the tracked `LiveChurchTranslation.xcodeproj` and shared
`LiveChurchTranslation` scheme. `APP_STORE_PROJECT`, `APP_STORE_WORKSPACE`, and
`APP_STORE_SCHEME` remain explicit overrides for a controlled release environment.

The scripts do not pass `-allowProvisioningUpdates` unless
`APP_STORE_ALLOW_PROVISIONING_UPDATES=1` is explicitly supplied. That opt-in lets
Xcode contact and update the developer account; use it only under the account
holder's release procedure.

For a manual export, additionally set:

```sh
APP_STORE_SIGNING_STYLE=manual \
APP_STORE_PROVISIONING_PROFILE='Exact Profile Name' \
APP_STORE_SIGNING_IDENTITY='Apple Distribution: Legal Name (ABCDEFGHIJ)' \
APP_STORE_INSTALLER_SIGNING_IDENTITY='Mac Installer Distribution: Legal Name (ABCDEFGHIJ)' \
APP_STORE_TEAM_ID=ABCDEFGHIJ \
./Scripts/export_app_store.sh
```

`Packaging/AppStoreExportOptions.plist` is a lintable template. The export script
copies it to a temporary file, injects the team and optional manual-signing values,
exports with `method=app-store-connect` and `destination=export`, verifies the
installer signature, records a SHA-256, and preserves the resolved options beside the
export. The template itself never contains a real team or secret.

Upload the resulting package only after Xcode Organizer or Transporter validation and
human approval. Upload is intentionally outside the scripts because it mutates App
Store Connect and requires account-scoped credentials. The Developer ID flow remains
separate:

- `package_release.sh` / `create_dmg.sh` / `notarize_release.sh`: direct website
  distribution using Developer ID and Apple notarization.
- `archive_app_store.sh` / `export_app_store.sh`: Mac App Store archive and package;
  no Developer ID identity, DMG, `notarytool`, or stapling.

## Privacy disclosure draft

The current production architecture processes microphone audio, imported audio,
speech recognition, translation, transcripts, glossary terms, diagnostics, and saved
meeting recordings on the Mac. It has no account system, analytics SDK, advertising,
tracking domain, or developer-operated content server. Opt-in LAN sharing sends the
live translation only to explicitly paired devices on the same network. The seven
revision-pinned model files are sealed into the signed app and load locally; the submitted
release does not download model data on first use. Debug source builds may use the pinned
Hugging Face installer, but that development behavior is not part of the submitted binary.

Based on that architecture, `PrivacyInfo.xcprivacy` declares no tracking and no app
data collection. It also declares the app-only `CA92.1` reason for the production
code's `UserDefaults` settings and `C617.1` for file metadata used only inside the
app container. The App Store Connect answer is expected to be **Data Not Collected**
for user audio and transcript content. Before every submission, the Account Holder
must still compare the exact shipping binary, Xcode privacy report, dependency
privacy manifests, bundled-model licenses and vendor policies, diagnostics behavior, and current
Apple definitions. Update both the manifest and App Store Connect if reality differs.

Publish `PRIVACY.md` at a stable public HTTPS URL and enter that URL in App Store
Connect. The bundled copy is useful in-app but does not replace the public privacy
policy URL. Suggested short disclosure:

> Live Church Translation processes speech, imported audio, translations, transcripts,
> and saved meeting recordings locally on your Mac. It does not use ads, analytics,
> or tracking. Live LAN sharing is off until you enable it and pair a device. The speech
> and translation models are bundled with the app; your audio and transcript are not uploaded.

The current `ITSAppUsesNonExemptEncryption=false` declaration is based on the app
using Apple-provided HTTPS/network security and one-way hashes rather than shipping
non-exempt encryption. The Account Holder must reconfirm export-compliance answers
for the exact binary; this document is not legal advice.

## App Review notes draft

Paste and adapt this text for the exact submitted build:

> Live Church Translation is a local-first macOS live transcription and translation
> tool. No account or test credentials are required. Choose Chinese to English or
> English to Simplified Chinese on the Live screen. The revision-pinned ASR and translation
> models are bundled in the signed app, verified before loading, and run locally without a
> first-use download. Before microphone capture begins, the host must confirm
> that participants have been informed that complete meeting audio and a transcript
> will be saved. A persistent red recording indicator remains visible until capture
> stops. The Library screen plays and deletes locally saved sessions and imports
> system-readable audio through the macOS file picker with read-only access. Optional
> LAN sharing is off by default; when enabled, Bonjour advertises
> `_churchtranslate._tcp` and only explicitly paired devices receive the live reader.
> The LAN reader uses authenticated HTTP/WebSocket on the trusted local network and
> does not contact a cloud transcription service. The bundled `llama-server` is a
> sandbox-inheriting child process used only through authenticated IPv4 loopback.

Attach a short review video if the review environment cannot provide a second LAN
device. Give the reviewer exact bundled-model verification and load timing measured on the
release candidate; do not promise translation perfection or theological infallibility.

## Submission checklist

- [ ] App Store Connect Bundle ID, version, build, SKU, category, age rating, support
      URL, privacy URL, copyright, and availability are approved.
- [ ] App icon and current macOS screenshots meet the sizes shown in App Store
      Connect and contain no unlicensed church branding or copyrighted sermon text.
- [ ] `THIRD_PARTY_NOTICES.md`, model licenses, llama.cpp license, sherpa-onnx license,
      and the grants required by [ScriptureStandards.md](ScriptureStandards.md) have
      legal approval.
- [ ] Machine-translated Scripture is presented as a translation aid rather than an
      authoritative quotation; bilingual pastoral review covers Scripture-reference
      preservation and App Review Guideline 1.1.5 risk.
- [ ] The archive audit passes with the intended team, distribution profile, helper
      entitlements, privacy manifest, Bundle ID, version, and build.
- [ ] The sandboxed release candidate passes microphone denial/regrant, recording
      consent/indicator, long-session recording, import, playback, delete, app relaunch,
      bundled-model verification/failure, network-disabled first launch, and disk-full/interruption tests.
- [ ] LAN sharing is off by default and passes pairing, revocation, hostile Host/Origin,
      network loss, and a real phone/tablet/computer matrix on a trusted network.
- [ ] VoiceOver, keyboard-only use, Reduce Motion, Increase Contrast, text scaling,
      Chinese/English wrapping, and supported window-size checks pass.
- [ ] Xcode's privacy report and App Store Connect privacy answers match the submitted
      package; recording law/consent copy has product and legal approval.
- [ ] Export compliance and content-rights questions are answered by the Account
      Holder for the exact build.
- [ ] Organizer or Transporter validation is clean; package SHA-256 and export log are
      attached to the release record before authorized upload.
- [ ] After processing, TestFlight/App Store sandbox installation passes on a clean
      Apple Silicon Mac using a standard (non-admin) user and an empty app container.

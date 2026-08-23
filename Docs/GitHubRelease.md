# GitHub Release candidates

The GitHub workflow builds reproducible macOS release candidates without treating packaging as
proof of product quality. The current tree remains **NO-GO** until every applicable gate in
[Testing](Testing.md) has current evidence. A green workflow must not be described as production
ready, theologically infallible, long-sermon validated, or clean-Mac validated.

## Trigger policy

`.github/workflows/release.yml` supports two paths:

- `workflow_dispatch` defaults to `dry_run=true`. It builds an ad-hoc app and DMG, runs the same
  inventory and size audits, uploads a seven-day Actions artifact, and makes no GitHub Release or
  Apple notarization mutation.
- A pushed `vMAJOR.MINOR.PATCH` tag, or a manual non-dry run explicitly selecting such a tag,
  requires an annotated tag on the default-branch history and formal credentials. It signs and
  notarizes the app and DMG, re-verifies the downloaded workflow artifact, creates a GitHub
  artifact attestation, and creates a **draft prerelease**.

The workflow never publishes a draft. A human owner reviews the evidence and the outstanding
release gates before deciding whether to publish it. Reruns refuse to overwrite an existing
GitHub Release for the same tag.

Repository owners must protect the default branch and configure the referenced
`production-release` GitHub Environment with required reviewers before enabling formal tags. All
Apple credentials belong in that environment, not in repository-level secrets.

All third-party Actions use immutable commit SHAs. The release job has read-only repository
permission; only the separate draft-creation job receives `contents: write`, `id-token: write`,
`attestations: write`, and the artifact-metadata permission required by the pinned attestation
action.

## Repository secrets

Formal runs fail before model transfer when any required secret is absent or malformed:

| Secret | Required value |
| --- | --- |
| `DEVELOPER_ID_APPLICATION` | Full `Developer ID Application: Legal Name (TEAMID)` identity |
| `RELEASE_SIGNING_CERTIFICATE_BASE64` | Base64-encoded Developer ID Application `.p12` |
| `RELEASE_SIGNING_CERTIFICATE_PASSWORD` | Password protecting that `.p12` |
| `APPLE_NOTARY_KEY_BASE64` | Base64-encoded App Store Connect API `.p8` private key |
| `APPLE_NOTARY_KEY_ID` | Ten-character API key ID |
| `APPLE_NOTARY_ISSUER_ID` | App Store Connect issuer UUID |

The workflow installs the certificate into an ephemeral keychain, writes the notary key with
mode `0600`, and removes both in an `always()` cleanup step. The GitHub token supplied to the
draft job is used only for attestation and draft creation. A Git commit email address is not an
authentication credential and should not be stored as a secret.

## Pinned inference assets

Release model weights are deliberately absent from Git. `Scripts/release_model_sources.tsv`
contains only immutable HTTPS source URLs. `Packaging/ProductionModels.sizes` and
`Packaging/ProductionModels.sha256` are the authoritative size and digest manifests. The fetcher
accepts a cached file only after both checks pass and otherwise uses a temporary `.part` file.

The seven model files total 2,120,095,795 bytes:

- Qwen3-ASR 0.6B INT8 at Hugging Face commit
  `68818b2313fe77bd06f6a7c5068ff3ef59d02b8a`.
- Hy-MT2 1.8B Q4_K_M at Hugging Face commit
  `1cd5208700acedef4ef93019b6cfc148b8522d45`.

The llama.cpp runtime is separately locked by archive and member hashes in
`Scripts/fetch_llama_runtime.sh` and `Packaging/LlamaRuntime.sha256`. Restored Actions caches are
never trusted without these checks.

## Formal build sequence

1. Validate tag shape and credential presence.
2. Restore, fetch, and cryptographically verify the seven model files and llama.cpp runtime.
3. Resolve exact Swift dependencies and run `Scripts/check.sh` through the packaging command.
4. Copy models to `Contents/Resources/Models` and helper code to `Contents/MacOS`.
5. Sign nested dylibs, sign `llama-server`, then sign the outer app with Developer ID, hardened
   runtime, a secure timestamp, and the reviewed entitlements.
6. Submit the app ZIP to `notarytool`, require `Accepted`, staple and validate the app, create and
   sign the DMG, then repeat notarization and stapling for the DMG.
7. Require Gatekeeper assessment and require the final DMG to be strictly smaller than
   2,147,483,648 bytes, GitHub's per-asset limit.
8. Generate evidence, upload it as an Actions artifact, download and re-verify it in the
   least-privilege draft job, attest the DMG, and create a draft prerelease.

Apple notarization and GitHub asset limits are external requirements; consult the current
[Apple notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
and [GitHub Releases documentation](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)
before changing this workflow.

## Evidence assets

Every candidate includes:

- `Quiet Liturgy Reader.dmg`;
- `SHA256SUMS` for the DMG and evidence files;
- `MODEL-MANIFEST.tsv` generated from the files actually sealed into the app;
- `RUNTIME-MANIFEST.sha256`;
- `LICENSE-MANIFEST.sha256`;
- `APP-CONTENTS.sha256`;
- `RELEASE-REPORT.md` with commit, version/build, toolchain, sizes, signing team, and notarization
  submission IDs/statuses; and
- raw successful `notarytool` JSON on formal runs.

The automated report intentionally says that it is packaging evidence only. Human release notes
must add the exact corpus decisions, review results, soak duration, latency and memory evidence,
LAN device matrix, privacy review, and clean standard-user Mac acceptance result required by
`Docs/Testing.md`.

## Local rehearsal

An ad-hoc rehearsal uses the same model and DMG checks but cannot be distributed:

```sh
APP_VERSION=0.0.0 APP_BUILD_NUMBER=1 DEVELOPER_ID_APPLICATION=- \
  ./Scripts/package_release.sh
DEVELOPER_ID_APPLICATION=- ./Scripts/create_dmg.sh
./Scripts/generate_release_evidence.sh
```

For a local formal run, either provide the three App Store Connect API key variables consumed by
`Scripts/notarize_release.sh`, or set `NOTARY_PROFILE` to a previously validated `notarytool`
Keychain profile. Never commit certificates, private keys, profile credentials, or generated
release assets.

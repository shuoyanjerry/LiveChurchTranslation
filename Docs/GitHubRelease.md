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

Packaging evidence is not translation-quality authority. Publishing also requires the exact HyMT
run's root-signed freeze attestation, byte-identical private review packet, root-signed reviewer
registry, and two-reviewer v2 settlement to pass the attested adjudication gate. The freeze authority
and reviewer-registry roots are source-pinned and cannot be supplied by workflow inputs. Both
production root sets are intentionally empty until real independent key governance and two actual
reviewers are provisioned; therefore the current repository remains formal-release **NO-GO** even if
a packaging workflow is green.

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
4. Clone models into `Contents/Resources/Models` on APFS when available and copy helper code to
   `Contents/MacOS`; the resulting app contains ordinary self-contained files.
5. Sign nested dylibs, sign `llama-server`, then sign the outer app with Developer ID, hardened
   runtime, a secure timestamp, and the reviewed entitlements.
6. Seal the app ZIP hash before submission, submit it to `notarytool`, require `Accepted`, and
   privately retain the submission JSON, Apple log, and submitted-artifact hash. The request ID,
   status, Apple-recorded SHA-256, sealed SHA-256, and unchanged local artifact must all agree.
   Staple and validate the app, create and sign the DMG, then repeat the same sealed submission and
   validation flow for the DMG.
7. Re-run `hdiutil verify` after the DMG ticket is stapled, require Gatekeeper assessment, mount the
   image read-only, simulate dragging the app into a fresh Applications directory, re-audit the
   relocated app, run its non-interactive installation probe, and require the final DMG to be
   strictly smaller than
   2,147,483,648 bytes, GitHub's per-asset limit.
8. Generate evidence, upload it as an Actions artifact, download and re-verify it in the
   least-privilege draft job, attest the DMG, and create a draft prerelease.
9. Before publication, verify the separately retained translation freeze, postflight, packet,
   reviewer registry, and signed settlement on the exact protected commit. The verifier must print
   `RELEASE_READY=true` only as its final line; caller-provided legacy "trusted SHA" values are not
   accepted.

The standard Apple Silicon `macos-15` runner has a 14 GB SSD. The workflow records free space,
requires at least 6 GiB before the release build and at least 5 GiB before DMG creation plus the
drag-copy audit, removes transient Swift build products after the app passes its audit, deletes the
app-notarization ZIP before creating the DMG, and removes the expanded app before artifact upload.
Packaging uses APFS clone copies for the model bundle and DMG staging. These are correctness guards
against a partially written candidate, not optional speed optimizations. See GitHub's current
[hosted-runner specification](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
before changing the thresholds or runner label.

Apple notarization and GitHub asset limits are external requirements; consult the current
[Apple notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
and [GitHub Releases documentation](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)
before changing this workflow.

## Evidence assets

Every candidate stores its evidence under `dist/Live Church Translation.release-evidence/`
and includes:

- `Live Church Translation.dmg`;
- `SHA256SUMS` for the DMG and evidence files;
- `MODEL-MANIFEST.tsv` generated from the files actually sealed into the app;
- `RUNTIME-MANIFEST.sha256`;
- `LICENSE-MANIFEST.sha256`;
- `APP-CONTENTS.sha256`;
- `RELEASE-REPORT.md` with commit, version/build, toolchain, sizes, signing team, and notarization
  submission IDs/statuses. Dry runs record whether local sources were dirty, while formal
  notarization refuses a dirty Git worktree before building and evidence generation rechecks it; and
- raw successful `notarytool` submission JSON, the corresponding Apple notarization log JSON, and a
  sealed SHA-256 file for each submitted artifact on formal runs. All six files must be ordinary,
  nonempty, runner-owned `0600` files. Evidence generation rejects duplicate JSON keys, mismatched
  request IDs or statuses, malformed hashes, and any Apple-recorded hash that differs from the
  sealed submitted-artifact hash. Their IDs, paths, and hashes are recorded in
  `RELEASE-REPORT.md`; credential values are never written by the release scripts.

The submitted DMG hash is intentionally recorded separately from the final DMG hash because
stapling adds the notarization ticket after Apple accepts the upload. Formal evidence generation
therefore also re-runs app and DMG ticket validation, final-DMG verification, and both Gatekeeper
assessments instead of treating the retained JSON as proof that the final files are usable.

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

The fixed local output path and supported-Mac installation contract are documented in
[DMG installation and supported Macs](DMGDistribution.md).

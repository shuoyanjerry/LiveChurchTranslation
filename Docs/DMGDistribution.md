# DMG installation and supported Macs

The public GitHub asset is always named `Live Church Translation.dmg`. A local candidate is written
to:

```text
/Users/shuoyan/Live_Church_Translation/dist/Live Church Translation.dmg
```

Only a Developer ID-signed, Apple-notarized, stapled candidate that passes the release evidence and
clean-Mac acceptance gates may be given to users. An ad-hoc engineering DMG at the same path is not
a distributable substitute.

## Supported installation

- Apple Silicon Mac (M1 or newer).
- macOS 15.0 or newer.
- At least 5 GB free while the downloaded DMG and installed app coexist.
- No Homebrew, Xcode, Python, Node.js, Ollama, command-line tool, or separate model download.

The application bundle contains the pinned speech-recognition model, translation model,
`llama-server`, its dynamic libraries, licenses, privacy manifest, reader assets, and app icon.
Release code loads only these bundled models. Intel Macs and macOS 14 or earlier are outside the
current support contract.

## Listener-visible installation flow

1. Download `Live Church Translation.dmg` from the project's GitHub Release.
2. Open the DMG.
3. Drag `Live Church Translation` onto the `Applications` shortcut.
4. Eject the DMG and open the app from Applications.
5. Approve the normal macOS microphone request. Approve local-network access only when sharing
   captions with listeners.

The app must not ask the user to install a runtime or expose packaging, model, server, or diagnostic
instructions in its interface.

## Automated candidate gates

`Scripts/audit_release_dmg.sh` mounts the final image read-only, checks the app-plus-Applications
layout, simulates the drag copy into a fresh Applications directory, rejects symlinks inside the
installed app, re-runs the signed app/resource/architecture audit, and executes the relocated app's
non-interactive installation probe. The app audit also rejects build-host dynamic-library paths and
requires every non-system Mach-O dependency to be bundled beside the executable.

Formal packaging additionally requires Developer ID Application signing, hardened runtime, secure
timestamps, Apple notarization of both app and DMG, stapled tickets, Gatekeeper acceptance, an exact
evidence manifest, and a final DMG smaller than GitHub's 2 GiB asset limit.

## Required clean-Mac acceptance

Automation does not replace a download test. Before publication, download the exact GitHub asset so
macOS applies quarantine, then test from a standard non-admin account on at least a base M1/8 GB Mac
and a newer M-series Mac. Cover macOS 15.0 and the latest supported 15.x release. On each machine:

- verify Gatekeeper acceptance, drag copy, eject, offline launch, and bundled-model readiness;
- approve microphone access and record a saved meeting;
- run one Chinese-to-English and one English-to-Chinese live segment;
- import a supported audio file and reopen its transcript and recording;
- quit, relaunch, and repeat model preparation without a download;
- enable sharing and open the listener page from iPhone, iPad, and another Mac on the LAN.

Record the DMG SHA-256, app version/build, Mac model/RAM, macOS version, signing team, notarization
request IDs, and results. Any failure keeps the GitHub Release in draft.

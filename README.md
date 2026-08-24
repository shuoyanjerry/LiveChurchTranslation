# Live Church Translation

[简体中文](README.zh-CN.md) | English

Live Church Translation is a privacy-focused macOS app for live Mandarin-to-English and
English-to-Simplified-Chinese translation. It records sessions, creates timestamped transcripts,
and can share a read-only live view with paired devices on a trusted local network.

## Features

- On-device speech recognition and translation with no cloud inference.
- Selectable audio input, complete local recording, crash recovery, and a searchable
  source-transcript library.
- Source-language transcription of imported WAV, AIFF/AIFC, AAC/M4A, and CAF recordings;
  imported audio is never translated.
- Editable terminology glossaries and automated output validation.
- A continuous reader with quiet processing status, optional source text and timestamps, and
  **Jump to Live**.
- Viewer-only LAN sharing for paired phones, tablets, and computers.

Automated validation reduces known structural errors but cannot guarantee linguistic or theological
accuracy. Important translations require qualified bilingual review.

## Requirements

- Apple Silicon Mac (M1 or newer).
- macOS 15.0 or later.
- At least 5 GB of free space while the installer and app coexist.

Packaged releases include verified models and runtime components. Users do not need to install
Python, Node.js, Ollama, or another inference runtime.

## Use

1. Open the app and allow microphone access.
2. Select the translation direction, audio input, and glossary.
3. Confirm that participants know the session will be recorded, then choose **Start**.
4. Read locally or enable **Share** for paired viewers on a trusted network.
5. Choose **Stop** to finalize the recording and transcript in **Library**.

Existing recordings can be imported from **Library** for source-language transcription only. Import
does not run translation.

## Privacy and local sharing

Speech recognition and translation run locally. The library retains recordings and recognized
source text, but not translations. Glossaries and recovery data also stay in the app's sandboxed
Application Support directory.

LAN sharing is off by default and gives viewers no control over recording or app settings. The
current reader transport uses authenticated HTTP/WebSocket without TLS, so enable it only on a
trusted local network and stop sharing when finished. Do not expose it through port forwarding or
untrusted public Wi-Fi.

See the [privacy policy](PRIVACY.md) for data-handling details.

## Build and verify

Validated with Xcode 26.6 (Swift 6.3.3). A warnings-as-errors app build and 45 focused compatibility
tests also pass with Swift 6.1. The quality gate requires Python 3 and ripgrep.

```sh
./Scripts/check.sh
```

## Documentation

- [Installation and supported Macs](Docs/DMGDistribution.md)
- [Architecture](Docs/Architecture.md)
- [Testing and release qualification](Docs/Testing.md)

## License and developer

Source code is available under the [MIT License](LICENSE). Models and third-party components retain
their own licenses; see [Third-Party Notices](THIRD_PARTY_NOTICES.md).

The sole developer and maintainer is
[shuoyanjerry](https://github.com/shuoyanjerry) (`jerryyanshuo@outlook.com`).

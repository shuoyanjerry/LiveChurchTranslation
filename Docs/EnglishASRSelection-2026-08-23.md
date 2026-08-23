# English ASR production selection — 2026-08-23

## Decision

Keep **Qwen3-ASR 0.6B INT8 through sherpa-onnx 1.13.6** as the production recognizer for
English-to-Simplified-Chinese mode. It is the only candidate that already has this app's complete
Swift adapter, theological context policy, artifact verification, failure guards, and exact-corpus
evidence. Parakeet TDT 0.6B v3 is the leading challenger because it is substantially faster, but it
did not beat Qwen's accuracy on the same English theological corpus.

This decision separates responsibilities deliberately: ASR must preserve what the speaker said and
recognize church vocabulary; Scripture-version and theological-language choices belong to the
translation and Scripture-reference layers.

## Research method

Deep research used Exa across model quality, Apple Silicon runtimes, model size and licensing,
streaming behavior, and Apple system APIs. The workstreams reviewed 230 returned source slots; search
duplicates were removed and conclusions use only model-author papers, official model cards, official
repositories, runtime documentation, and Apple documentation. Cross-vendor benchmark values are
treated as directional because their corpora and normalization differ.

Selection weights were:

- church-domain accuracy and context biasing: 35%;
- base M1 8 GB feasibility: 25%;
- real-time behavior: 20%;
- model license: 10%;
- offline Swift integration maturity: 10%.

Scores within 0.1 are effectively tied until a blinded, licensed human-sermon A/B resolves them.

| Rank | Candidate | Weighted score | Production finding |
| ---: | --- | ---: | --- |
| 1 | Qwen3-ASR 0.6B INT8 + sherpa-onnx | **9.03** | Current accuracy winner and complete production path |
| 2 | Parakeet TDT 0.6B v3 INT8 + sherpa-onnx | **9.02** | Fastest close challenger; same-corpus accuracy was lower |
| 3 | WhisperKit compressed large-v3 Turbo | 8.99 | Strong Core ML option, but no same-corpus or base-M1 evidence |
| 4 | Parakeet Unified INT8 + FluidAudio | 8.87 | Best interim-token candidate; custom vocabulary and M1 remain unqualified |
| 5 | Moonshine Streaming Medium | 8.54 | Small and low-latency, but lower accuracy and weaker macOS packaging path |
| 6 | Fun-ASR Nano INT8 + sherpa-onnx | 7.92 | Existing challenger did not beat Qwen in repository A/B evidence |
| 7 | Whisper Turbo + MLX | 7.40 | Effective research runtime, not an appropriate Python-free Swift delivery path |
| 8 | Whisper large-v3 + MLX/whisper.cpp | 6.39 | Memory and latency are unsuitable for the minimum dual-model workload |

## Same-corpus Apple Silicon A/B

Both candidates decoded the exact 18 locally generated clips used by the production English gate:
190 reference words, seven voices, six English locales, and 68.7480625 seconds of audio. Tests used
four CPU threads on the same M1 Pro 16 GB host.

| Candidate | Context | Word errors | WER | RTF |
| --- | --- | ---: | ---: | ---: |
| Qwen3-ASR 0.6B INT8 | Exact production 18-term glossary prompt | **2 / 190** | **1.0526%** | 0.19144 |
| Parakeet TDT 0.6B v3 INT8 | Greedy decode, no hotword file | 5 / 190 | 2.6316% | **0.03982** |

Parakeet was about 4.81 times faster, but produced three additional word errors. Its errors included
`Jesus` → `Jes`, an inserted `in`, and `praises God` → `prays as God`. Qwen's two retained errors were
`Prayer` → `Greer` and `the congregation` → `a congregation`.

The Parakeet run used the official sherpa-onnx 1.13.6 arm64 wheel and official v3 INT8 archive. The
465 MiB archive SHA-256 was
`5793d0fd397c5778d2cf2126994d58e9d56b1be7c04d13c7a15bb1b4eafb16bf`; its extracted model was
about 639 MiB. That archive did not contain the `bpe.vocab` needed by the tested sherpa hotword path,
so the result does not establish Parakeet custom-vocabulary quality.

The corpus is a deterministic wiring and terminology regression, not proof of arbitrary human-sermon
accuracy. It contains synthesized voices rather than room reverberation, music, overlapping speakers,
or spontaneous delivery.

## Why Qwen remains the common M-series engine

The Qwen authors describe the 0.6B model as the accuracy-efficiency variant intended for on-device
deployment, with English and Chinese accounting for most training data and explicit context-biasing
training. The sherpa-onnx port publishes an INT8 model, Swift API, CPU execution, and macOS arm64
support. This app pins every model artifact and the sherpa runtime, uses a bounded 18-term theological
prompt, and has prompt-echo, repetition, silence, and single-retry guards.

The application, sherpa framework, and bundled llama.cpp helper all contain generic arm64 slices; the
recognizer uses four CPU threads and no model-generation-specific instruction or accelerator. This is
the portable binary path across M-series Macs running the macOS 15 deployment target.

Apple's SpeechTranscriber is attractive because its assets are system-managed and its model runs
outside the app's memory space, but SpeechAnalyzer begins at macOS 26 and requires a runtime
`isAvailable` check. It therefore cannot replace the pinned macOS 15 engine. WhisperKit and Parakeet
Unified remain useful experiments, especially if interim word display becomes a requirement, but a
second recognizer must not be kept resident by default on a base M1.

## Minimum-hardware qualification boundary

The current exact English run was performed on an M1 Pro with 16 GB RAM. The arm64 architecture is
compatible with all M-series generations, but performance on a base M1 with 8 GB has not been measured
physically. Do not turn architecture compatibility into an unsupported performance claim.

Before a release says “qualified on every M-series class,” the exact app build must pass on a base M1
8 GB with Qwen (987,015,347 bytes) and Hy-MT2 (1,133,080,448 bytes) loaded together: cold launch,
automatic download and retry, two hours of consented human sermon audio, reverberation/music/noise,
peak RSS, swap and memory pressure, thermal throttling, ASR RTF, and sentence-end-to-reader p50/p95.
M2 through the latest M-series then require compatibility smoke tests, while a blinded shared corpus
compares WER, church-term recall, and hallucination rate.

## Primary sources

- [Qwen3-ASR technical report](https://arxiv.org/html/2601.21337v2)
- [Qwen3-ASR 0.6B official model card](https://huggingface.co/Qwen/Qwen3-ASR-0.6B-hf)
- [sherpa-onnx Qwen3-ASR documentation](https://k2-fsa.github.io/sherpa/onnx/qwen3-asr/pretrained.html)
- [sherpa-onnx official repository](https://github.com/k2-fsa/sherpa-onnx)
- [NVIDIA Parakeet TDT 0.6B v3 model card](https://huggingface.co/nvidia/parakeet-tdt-0.6b-v3)
- [sherpa-onnx Parakeet v3 export](https://github.com/k2-fsa/sherpa-onnx/pull/2500)
- [NVIDIA Parakeet Unified model card](https://huggingface.co/nvidia/parakeet-unified-en-0.6b)
- [FluidAudio Core ML benchmarks](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/Benchmarks.md)
- [OpenAI Whisper model card](https://github.com/openai/whisper/blob/main/model-card.md)
- [WhisperKit paper](https://arxiv.org/html/2507.10860)
- [Moonshine Streaming model card](https://huggingface.co/moonshine-ai/moonshine-streaming-tiny)
- [Apple SpeechAnalyzer documentation](https://developer.apple.com/documentation/speech/speechanalyzer)
- [Apple WWDC25 SpeechAnalyzer session](https://developer.apple.com/videos/play/wwdc2025/277/)


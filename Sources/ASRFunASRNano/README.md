# ASRFunASRNano

## Purpose

Isolated, replaceable Apple-Silicon challenger implementing `ASRProvider` with the
Fun-ASR-Nano-2512 INT8 export supported by pinned sherpa-onnx 1.13.6. It is not wired
into `ChurchTranslatorApp`; Qwen3-ASR remains the production default.

## Public API

`FunASRNanoProvider`, immutable `FunASRNanoConfiguration`, and stateless
`FunASRNanoModelVerifier` are the only public types. The model directory must contain
`encoder_adaptor.int8.onnx`, `embedding.int8.onnx`, `llm.int8.onnx`, and the
`Qwen3-0.6B` tokenizer directory. Loading fails before native initialization unless all
six files match the pinned byte counts and SHA-256 identities.

## Dependencies

Depends only on `ASRAPI` and the pinned sherpa-onnx adapter. No Python, Node, model SDK,
or user-installed runtime is involved.

## Threading model

An actor owns the recognizer and serializes load, decode, and unload. Requests and results
cross the boundary as immutable `Sendable` values.

## Failure modes

Incomplete layout, unloaded model, empty audio, low-energy nonspeech, empty decoding, and
pathological repetition surface as typed `ASRError` values. sherpa-onnx 1.13.6 binds
Fun-ASR language and hotwords when constructing the recognizer; per-request
`contextPrompt` is therefore not applied. Callers may inject stable hotwords through the
configuration, but changing them requires recreating the provider.

## Model provenance

The download script fixes GitHub release asset `394517157`, filename
`sherpa-onnx-funasr-nano-int8-2025-12-30.tar.bz2`, 841,730,611 bytes, SHA-256
`eb43d7ccc2e86b243f6a03b7df361033dda66db9523d1a92bf6aca2b50c9476b`. The asset URL is
`https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/` plus the filename.

The corrected export corresponds to ModelScope snapshot
`zengshuishui/FunASR-nano-onnx@2fbcc2ea1b60a2d579f2a8e921cac6023c61789d`.
Every required extracted file is independently checked:

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `embedding.int8.onnx` | 155,583,106 | `a05d2816e284fcca29a5dccb2c14b9edeb638fd983a84cd4a447248889b6a408` |
| `encoder_adaptor.int8.onnx` | 238,277,200 | `d0246c823f2c34133ae0efee395d8a189c8f92643e3432f866939ee34d34492c` |
| `llm.int8.onnx` | 600,339,316 | `7f0c5a508b41474b1b1ec1cdbdefafd2cf8b3642c6915a0a425265b7b7d2c960` |
| `Qwen3-0.6B/merges.txt` | 1,671,853 | `8831e4f1a044471340f7c0a83d7bd71306a5b867e95fd870f74d0c5308a904d5` |
| `Qwen3-0.6B/tokenizer.json` | 11,422,654 | `aeb13307a71acd8fe81861d94ad54ab689df773318809eed3cbe794b4492dae4` |
| `Qwen3-0.6B/vocab.json` | 2,776,833 | `ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910` |

The six extracted files total 1,010,070,962 bytes. The compatibility LLM is required;
the older 600,356,593-byte file is rejected because sherpa-onnx issue 3066 and pull request
3493 document its repetition/corruption failure and replacement.

The upstream model card identifies Apache-2.0. The sherpa export README attributes
ModelScope `zengshuishui/FunASR-nano-onnx`; retain all applicable notices before any
redistribution. Challenger weights remain gitignored under `.artifacts` and are not
bundled in release artifacts.

## Tests

`ASRFunASRNanoTests` covers configuration, layout validation, silence gating, repetition,
provider lifecycle and an environment-gated same-machine Qwen/Fun-ASR fixed-clip A/B. A
public-domain Scripture harness consumes only the shared, exact-hash Manifest V2 loader and
Report V3 builder from `ASRQualificationSupport`. It verifies source WAV and model-input PCM
identities, raw reference-manifest provenance, the complete clip set, and all six model files
before native initialization. The qualification configuration is frozen at two threads,
Mandarin, 192 output tokens, 0.003 minimum RMS, and the 13-term theology hotword list. Former
cumulative-time reports remain invalidated; model-quality evidence never changes production
selection automatically.

# Fun-ASR-Nano challenger qualification — 2026-08-22

## Decision

Fun-ASR-Nano-2512 INT8 is integrated only as an isolated `ASRProvider` challenger.
It is **not promoted** and is not linked into `ChurchTranslatorApp`; Qwen3-ASR remains the
production default. The fixed-clip evidence is encouraging but too small for selection, and
the first public-corpus attempts were invalidated by a boundary-timebase defect.

## Exact implementation and model

- Adapter: `ASRFunASRNano`, depending only on `ASRAPI` and sherpa-onnx.
- Runtime: sherpa-onnx 1.13.6, exact package tag, CPU execution on Apple Silicon.
- Upstream model: FunAudioLLM Fun-ASR-Nano-2512, model-card revision
  `272c57b82523ada6fd87095e955f8e29100979ab`, Apache-2.0.
- Corrected ONNX snapshot: ModelScope `zengshuishui/FunASR-nano-onnx` revision
  `2fbcc2ea1b60a2d579f2a8e921cac6023c61789d`.
- Official sherpa release asset: GitHub asset `394517157`, 841,730,611 bytes, SHA-256
  `eb43d7ccc2e86b243f6a03b7df361033dda66db9523d1a92bf6aca2b50c9476b`.
- Correct compatibility LLM: 600,339,316 bytes, SHA-256
  `7f0c5a508b41474b1b1ec1cdbdefafd2cf8b3642c6915a0a425265b7b7d2c960`.
- Extracted required files: 1,010,070,962 bytes total. The module README records every
  individual byte count and SHA-256.
- Weights remain gitignored under `.artifacts`; the app and repository do not embed them.

The compatibility LLM is mandatory. sherpa-onnx issue 3066 and pull request 3493 document
the older file's broken repetition/corruption behavior and its replacement. The reproducible
developer fetch script verifies the archive and all six required extracted files before use.

## Adapter boundary

`FunASRNanoProvider` is an actor implementing the existing immutable `ASRProvider` contract.
The recognizer is private and serialized across load, decode, and unload. Layout validation
rejects missing, symlinked, wrong-size, or wrong-SHA artifacts before the native wrapper can
initialize. Qualification also performs this exact six-file check before calling `loadModel`.
Typed `ASRError` failures cover lifecycle, empty/low-energy audio, empty decode, and
pathological repetition.

sherpa-onnx 1.13.6 fixes Fun-ASR language and hotwords when the recognizer is constructed.
The adapter therefore exposes stable `staticHotwords`; it cannot honestly support per-request
`contextPrompt` without recreating the recognizer. Sentence-level offline decode is suitable
behind VAD, not genuine streaming ASR.

## Valid fixed-clip exploratory A/B

The fixed-clip harness reads explicit file-local `startSeconds` and `durationSeconds` values.
It does not consume the invalid public-corpus boundary file. Seven clips cover synthetic
theology, the requested Argyle 2025 pronoun case, and five public-sermon voices, totaling
100.166 seconds, plus three seconds of synthetic silence per provider.

| Observation | Fun-ASR | Qwen3-ASR |
| --- | ---: | ---: |
| Expected phrase hits | 9 / 11 | 8 / 11 |
| Synthetic theology hits | 4 / 5 | 3 / 5 |
| Argyle expected-term hits | 4 / 4 | 4 / 4 |
| Adapter-visible silence text | none | none |
| Pathological repetition rejected/observed | 0 / 0 | 0 / 0 |

On the synthetic theology sentence, Fun-ASR preserved 救恩、恩典、因信称义、圣灵 but
substituted 重生 for 成圣. Qwen preserved 救恩、恩典、圣灵 but missed 因信称义 and 成圣.
Neither model fixed the held-out Argyle spoken-pronoun error. Fun-ASR avoided a trailing English
fragment emitted by Qwen on that clip. Other voices were mixed: Fun-ASR omitted interpreted
speech in one clip but made worse lexical/negation errors in others. These observations do not
constitute CER or human-reviewed theological accuracy.

The initial fixed-clip timing was not preceded by a full competing-process audit, so its RTF
numbers are exploratory only. Full raw text remains in the gitignored local `ab-results.json`
for audit and is not reproduced here.

## Invalidated public-corpus attempts

Every Fun-ASR report that used sibling `qwen3-asr-06b-q8-zh.predictions.json` is invalid.
That file's `end_ms` is cumulative retained-VAD duration, not absolute position in the source
WAV. The original harness treated it as a contiguous absolute timeline, decoded wrong audio,
and omitted 12.976 seconds from Mark 1. Removing CPU competition did not repair this defect.

Invalidated files are retained only under `.artifacts` with an explicit invalidation sidecar:

- `funasr-public-spiritual-mark1.json`
- `funasr-public-spiritual-mark1-fair.json`
- `funasr-mark1-clean-threads2.json`
- `funasr-mark1-clean-threads4.json`
- `funasr-mark1-clean-threads6.json`

Their CER, pronoun, latency, RTF, memory, and apparent 2/4/6-thread ranking must not be used for
model selection or release qualification. The aborted six-clip run produced no report.

The replacement harness accepts only provider-neutral Manifest V2, fixed at SHA-256
`8a485214b1c3fe01a931ec52bf14a59d409c3746b4e2e33dd28d0a80858302c8`. The shared
`ASRQualificationSupport` decoder and WAV loader enforce absolute half-open sample ranges,
source-WAV identity, exact model-input PCM identity, and the complete six-clip set. The raw
reference manifest must match the provenance SHA before its text is accepted; edge policy is
read only from Manifest V2. Results use shared Report V3 metrics and timing, including every
failed attempt in the three-second denominator and redacted stable failure codes. No
replacement corpus report has now been run over all 220 absolute PCM ranges. Fun-ASR and
Qwen consumed identical `{clip, sequence, inputSampleCount, pcmSHA256}` identities; the
identity-list SHA-256 was `88d0a84d3efb528de329f87cb795a46ead22c5e2a9fb5864db7feb51fcb3a027`
for both reports. There were no provider failures in either arm.

| Frozen Manifest V2 result | Fun-ASR Nano, 2 threads | Qwen3-ASR, 4 threads |
| --- | ---: | ---: |
| Edge-free semi-global CER | 4.8652% | **3.6152%** |
| Strict CER | 11.0172% | **9.9632%** |
| p50 attempt latency | 2.354 s | **2.005 s** |
| p95 attempt latency | **3.138 s** | 3.177 s |
| Attempts within 3 s | 87.73% | **94.55%** |
| Decode RTF | 0.17954 | **0.15800** |

Fun-ASR preserved three more reference-labelled pronoun glyphs than Qwen, but spoken
Mandarin *tā* does not acoustically encode gender; this difference cannot be treated as a
gender-accuracy advantage. Qwen has the better overall character fidelity, median latency,
three-second rate, and RTF on the same inputs. The Fun report SHA-256 is
`c1cdeab8b15359eef0d8ef6f5df38b960ba46f20ba345a6afea9cfb3fbfaa2ba`; the selected Qwen
four-thread report SHA-256 is
`db936183c0f5d082760f6840de1c43e1fbce8eb981d570b7c10a2100243eb17c`. Background-load
notes make both timing sets exploratory, but content metrics are paired and valid.

## Automated evidence

- Focused adapter, artifact-integrity, frozen-policy, and reference-provenance tests: 15 passed.
- `ASRFunASRNano` warnings-as-errors build: passed.
- Targeted Swift Format strict: passed.
- Targeted SwiftLint strict: 0 violations in 29 challenger source/test files.
- Source and test files: all below 200 lines.
- Model download/archive verification and production six-file byte/hash guard: passed.

## Remaining gates

The paired Manifest V2 run does not justify promotion: Fun-ASR is worse on both CER metrics,
median latency, three-second rate, and RTF, while its small pronoun-glyph difference is not an
acoustically meaningful gender result. Qwen therefore remains the production default. Both
models still miss the ≥98% three-second release gate. Before reconsidering Fun-ASR, obtain a
controlled-load rerun with separate model-load and recognizer-process memory, then expand to
multiple rooms, accents, music, singing, silence, interpreter overlap, and human-reviewed
sermon references. A six-clip Scripture corpus, vendor benchmark, or adapter guard cannot
justify a production switch by itself.

# Scripture production-model qualification — 2026-08-23

## Decision

The exact candidate is **NO-GO** for Scripture model qualification. The one-shot sealed
run completed all 36 lane attempts with zero execution failures, but Simplified Chinese
ASR recorded 12 edits over 147 reference characters: **8.1633%**, above the frozen
**8.0%** maximum. The other five lanes passed their frozen gates. A near miss is still a
failed release gate; `qualified` is therefore `false`.

This decision applies to the pinned corpus, models, runtimes, policy, and selector tested
below. It is not a general claim that either model is accurate or inaccurate for every
sermon, speaker, acoustic condition, or sentence length.

## Bound evidence

The reports use schema 2, contain aggregate evidence only, and contain no reference text,
ASR hypothesis, generated translation, declaration contents, or private source path.

| Evidence | Identity |
| --- | --- |
| Corpus | `official-scripture-exact-bilingual-v1` |
| Manifest SHA-256 | `c785b6298527d2eaf3761825b9ffb13c1ba55e8eaa2cd5b0716054d0f3e0eb3d` |
| Gate policy | `scripture-production-sealed-v1-frozen-2026-08-23` |
| Development A4 report SHA-256 | `898b4edb843f6bd3684c62cb8610a59eb04f45c6c32496979a7d244f3f5e95c6` |
| Sealed report SHA-256 | `7a8ce5903ccd67ae37f1d045e112a840b6815663cebee397086a3d7b97e7b9d8` |
| Qwen model revision | `qwen3-asr-0.6b-int8-2026-03-25` |
| Qwen model SHA-256 | `6f8c38de9f980542a9c5e7f2c2297adc20f2be91655d9a115c5eb36b04373eb2` |
| Qwen runtime | `sherpa-onnx@1.13.6` |
| Hy-MT2 model revision | `1cd5208700acedef4ef93019b6cfc148b8522d45` |
| Hy-MT2 model SHA-256 | `dc5f44fcf1fa496ee7ad725982c0c8c553a4de00259b53af84c4b89fb0c06699` |
| llama.cpp runtime revision | `b10549` |
| llama-server SHA-256 | `d0878274b8d6bd3c8ea26a78eb66cd1ffd943d007c62b9dff31c8aa99922d713` |
| llama.cpp runtime-bundle SHA-256 | `6100cd500aa29e3abc4d5f698f7ba2579877c506d64eab68417974c9fe610304` |

The corpus source declarations permit private text/audio evaluation and non-weight model
adjustment while prohibiting model training and redistribution. No model weight was
changed and no training was performed.

## Development-only adjustment history

All adjustment decisions used the six-pair development partition only. The fixed
intervention surface was the production Mandarin context selector: term choice, ordering,
and prompt length. Translation files, model weights, corpus content, manifest, references,
sealed items, and gate thresholds were not adjusted.

| Candidate | Mandarin prompt tokens | Chinese ASR CER | English ASR WER | Execution failures | Disposition |
| --- | ---: | ---: | ---: | ---: | --- |
| Starting bounded core | 62 | 22/195 = 11.2821% | 2/143 = 1.3986% | 0 | Replaced |
| A1, difficult names and theological forms | 70 | 20/195 = 10.2564% | 2/143 = 1.3986% | 0 | Replaced |
| A2, shorter 14-term prompt | 51 | 23/195 = 11.7949% | 2/143 = 1.3986% | 0 | Rejected |
| A3, reordered 16-term prompt | 62 | 16/195 = 8.2051% | 2/143 = 1.3986% | 1 downstream strict-term failure | Replaced |
| A4, minimal duplicate-term removal | 59 | **15/195 = 7.6923%** | **2/143 = 1.3986%** | **0** | Frozen before sealed run |

A4 was frozen because it crossed the development Chinese-ASR target without regressing
English ASR and restored zero failures. Development reports intentionally contain no
release gates and always have `qualified = false`.

### Frozen A4 aggregate

Every lane completed six attempts successfully. Average runtime is provider execution
time per attempt, not microphone-to-reader latency.

| Lane | Aggregate error | Average runtime | RTF | Failures |
| --- | ---: | ---: | ---: | ---: |
| English ASR | 2/143 = 1.3986% WER | 1.3481 s | 0.1856 | 0 |
| Simplified Chinese ASR | 15/195 = 7.6923% CER | 1.2856 s | 0.1615 | 0 |
| English clean text → Simplified Chinese | 131/195 = 67.1795% CER | 0.6988 s | n/a | 0 |
| Simplified Chinese clean text → English | 105/143 = 73.4266% WER | 0.8252 s | n/a | 0 |
| English ASR → Simplified Chinese | 134/195 = 68.7179% CER | 1.7854 s | 0.2458 | 0 |
| Simplified Chinese ASR → English | 101/143 = 70.6294% WER | 1.7596 s | 0.2210 | 0 |

## One-shot sealed result

The sealed partition was opened only after A4 and the gate policy were frozen. Each lane
had six attempts and required zero failures. ASR and ASR-to-translation lanes also had a
real-time-factor gate.

| Lane | Observed aggregate | Maximum error | Average runtime / maximum | RTF / maximum | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| English ASR | 2/131 = 1.5267% WER | 12.0% | 1.1195 / 30 s | 0.1467 / 1.25 | PASS |
| Simplified Chinese ASR | **12/147 = 8.1633% CER** | **8.0%** | 0.9557 / 30 s | 0.1658 / 1.25 | **FAIL** |
| English clean text → Simplified Chinese | 99/147 = 67.3469% CER | 70.0% | 0.5968 / 30 s | n/a | PASS |
| Simplified Chinese clean text → English | 87/131 = 66.4122% WER | 75.0% | 0.6411 / 30 s | n/a | PASS |
| English ASR → Simplified Chinese | 96/147 = 65.3061% CER | 80.0% | 1.5032 / 45 s | 0.1969 / 4.0 | PASS |
| Simplified Chinese ASR → English | 94/131 = 71.7557% WER | 85.0% | 1.3362 / 45 s | 0.2318 / 4.0 | PASS |

All sealed lanes recorded zero execution failures. The Chinese-ASR miss is 0.1633
percentage points above the limit. It is not rounded down and is not waived because the
other lanes passed.

The translation error rates are strict surface-distance measurements against one pinned
paired reference. Passing those deliberately broad gates proves bounded regression
behavior for this corpus; it does not prove semantic equivalence, theological perfection,
or pastoral acceptability.

## Sealed-data discipline

The sealed result must not guide another hotword, prompt, glossary, decoding, threshold,
or model change. Doing so would convert the observed partition into development data and
invalidate a later claim that it remained blind. The failure remains recorded as NO-GO.

A future candidate may be improved using independent development evidence, frozen, and
then tested against a new, previously unobserved sealed partition under a precommitted
gate. The existing sealed partition must not be repeatedly queried until it passes.

## Product and real-time boundary

The edition-pinned references establish a private evaluation baseline only. Generated ASR
and translation are live listening aids, not exact ESV 2025 or CUNPSS-神 1988 Bible
quotations. They must not be labelled authoritative, publisher-endorsed, infallible, or
verbatim. Exact quotation requires a separately permitted, version-pinned, hash-verified
source path and must preserve the supplied text exactly.

The observed sub-real-time provider RTF and sentence-sized average runtimes support a
component-performance claim on this small corpus only. They do not establish an end-to-end
sentence-at-a-time SLA: microphone capture, endpoint detection, queueing, persistence,
network projection, and phone/tablet/computer rendering were outside this qualification.

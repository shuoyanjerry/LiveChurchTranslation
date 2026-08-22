# Mandarin Discourse and Endpoint Qualification — 2026-08-21

## Status and decision

This is an engineering evidence report, not a production certificate. The selected live
path is a calibrated bounded policy driven by a pinned native libfvad/WebRTC classifier
plus the measured sermon energy rescue. AdaptiveEnergy remains a replaceable fallback.
Mandarin pronoun repair is deterministic, audited, and deliberately narrow. Pipecat Smart
Turn v3.2 has a native adapter but remains an offline **shadow signal**: it does not close
live sermon segments.

The reason is asymmetrical risk. A late boundary costs latency; an unsafe early boundary
can remove the linguistic context needed by both ASR and translation. Likewise, abstaining
on an ambiguous pronoun is preferable to silently assigning the wrong person or deity.

## Mandarin `ta`: what attention cannot recover

Spoken Mandarin does not acoustically distinguish `他`, `她`, `它`, and often `祂`: they
share the pronunciation *tā*. This is an information limit, not an ASR attention defect.
Attention or a larger language model can use discourse evidence, but cannot recover a
gender that the audio and surrounding discourse never supplied. The published
[TaCorrect study](https://aclanthology.org/2024.lrec-main.360/) confirms both the homophone
problem and the value of semantic/rule-assisted post-processing; it does not justify an
unconditional rewrite. Work on
[context-aware translation](https://aclanthology.org/2023.emnlp-main.943/) likewise reports
that apparently sensible document-context methods often provide only modest gains.

The implemented sequence is therefore:

```text
raw Qwen text
  -> literal ASR normalization with audit
  -> DiscourseResolutionAPI
  -> glossary matching and Hy-MT2
  -> output validation
  -> durable append
  -> admit the finalized pair to the next two turns of context
```

`DiscourseResolutionCore` is pure Swift and stateless. It accepts at most the preceding
two durably appended, validator-approved turns. It changes only an eligible singular
sentence/clause-leading `他` or `她` when exactly one explicit, allowlisted gender anchor
identifies that candidate. A request can change at most its first independently verified
candidate; the evidence is never propagated to later sentences or clauses. It abstains for
competing anchors, mixed `他` / `她` candidate spellings, quotations, plurals, deity
references, lexical substrings, stale or misordered context, names, occupations, and evidence
that appears only after the candidate. Every accepted change stores the original character,
replacement, source range, reason, policy confidence, and evidence turn. Raw ASR remains in
the transcript.

Hy-MT2 receives only the same latest two finalized pairs as non-output background. Its
prompt says that spoken *tā* can be ambiguous, forbids stereotypes, and requests singular
`they` when evidence is absent. Prompting is defense in depth, not the correction engine.

The private safety-regression set contains five reviewed cases from three Mandarin spiritual
messages (four source/session units): four cases safely repair one independently evidenced
`他` → `她`, and one quotation/speaker-shift case requires abstention. All five policy
expectations pass. The reference text contains seven desired corrections in total, but the
Argyle 2023 case places four masculine Qwen spellings after one earlier female anchor. The
resolver repairs only the first and explicitly protects the remaining three; treating one
anchor as proof for every later clause was rejected as unsafe. Context prompting alone made
the real Hy-MT2 Q4 model emit masculine `He/his`. A prior permissive experiment produced
consistent `She/her`, but that result is no longer a release claim because it reused evidence
across candidates. The measured theological translations took 0.461–0.864 seconds each.

A sixth reviewed case from Argyle 2025 is deliberately recorded as a known coverage gap:
the official manuscript says Pharaoh's daughter entered the palace built for **her**, while
both tested Qwen paths produced `为他建的宫殿`. The passage also contains Solomon and a
direct quotation, so a gender-word replacement would be unsafe. The resolver abstains and
retains the raw source for review. These six cases are coverage evidence, not an accuracy
rate, and the unresolved object-pronoun case prevents any claim of perfect pronoun handling.

## Calibrated sentence boundary policy

The boundary policy and the speech/non-speech classifier are separate injected concerns.
The timing profile analyzes 20 ms windows and applies these ordered constraints:

- short utterances below 3.5 seconds wait for 950 ms endpoint silence;
- other ordinary completion uses 650 ms endpoint silence;
- after 9 seconds of speech, a 500 ms pause may produce a soft boundary;
- from 15 seconds, close at the first stable 3-of-5 acoustic non-speech boundary;
- at 16.5 seconds, close at the hard cap if no safe pause appeared;
- two consecutive **raw** voiced windows cancel an endpoint pause immediately, rather
  than waiting for the five-window smoothed vote to recover.

The raw-resume rule separates speech resumption from start/noise smoothing. The bounded
15–16.5 second policy avoids the previous 27-second hard cut while preserving a grace
window for a natural pause. The live classifier is libfvad mode 2 OR the sibling project's
measured strong-energy rescue; the energy-only implementation remains available only as a
fallback. Timing and VAD still cannot distinguish sermon speech from singing with perfect
reliability. This follows the broader evidence that
semantic sentence boundaries can improve long-form ASR, while segmentation still requires
an explicit latency policy: see the
[Interspeech semantic segmentation study](https://www.isca-archive.org/interspeech_2023/huang23b_interspeech.html)
and the
[adaptive simultaneous-translation segmentation study](https://aclanthology.org/2020.emnlp-main.178/).

## Four-hour sermon endpoint replay

Four publicly accessible church recordings were replayed locally: two Argyle Road Baptist
Church Mandarin sermons and two Friendship Agape Mandarin sermons with live English
interpretation. The decoded 16 kHz mono WAV replay was 14,514.465 seconds (4 h 1 m 54 s).
No time-aligned human boundary labels were available, so these measurements describe
behavior, not boundary accuracy.

| Detector and timing profile | Segments | Under 2 s | Hard 16.5 s | Preferred boundary |
| --- | ---: | ---: | ---: | ---: |
| Selected Swift libfvad hybrid + stable boundary | 1,063 | 2.73% (29) | 366 | 288 |
| Same Swift classifier + 500 ms wait after 15 s | 1,042 | 2.69% (28) | 612 | 31 |
| Python reference implementation of selected policy | 1,072 | 2.71% (29) | 365 | 294 |
| Swift AdaptiveEnergy fallback + calibrated timing | 1,622 | 14.30% (232) | not recorded | not recorded |

The selected stable-boundary policy traded one additional short segment for 246 fewer hard
cuts than waiting 500 ms after 15 seconds. Swift and the Python reference differ by nine
segments because Swift conservatively requires the 500 ms soft pause to begin after the
9-second eligibility point. Their hard-cut counts differ by one.

The native adapter vendors unmodified libfvad at commit
[`532ab666c20d3cfda38bca63abbb0f152706c369`](https://github.com/dpirch/libfvad/tree/532ab666c20d3cfda38bca63abbb0f152706c369)
under BSD-3-Clause plus its patent grant. Its C sources compile as C11 with all common
warnings promoted to errors. On the four recordings, 725,722 individual 20 ms frames were
compared against the sibling project's pinned WebRTC VAD implementation: both marked
642,571 frames voiced, with **zero frame mismatches**. This proves classifier parity, not
semantic boundary accuracy. Aggregate segment counts still require a locked, manually
labelled set before production-quality claims.

## Smart Turn v3.2: native adapter, shadow policy

The isolated `SemanticEndpointSmartTurn` adapter uses Accelerate plus ONNX Runtime 1.27.1;
the shipping App needs no Python. It consumes 16 kHz mono audio, keeps or left-pads the
last eight seconds, creates the official-shape `[1, 80, 800]` log-mel tensor, verifies the
model hash before loading, and returns probability plus threshold through
`SemanticEndpointAPI`.

- Upstream model: [`pipecat-ai/smart-turn-v3`](https://huggingface.co/pipecat-ai/smart-turn-v3)
- Revision: [`f766f81d3cfdf7737ac64aad813d91bbfd56bf93`](https://huggingface.co/pipecat-ai/smart-turn-v3/commit/f766f81d3cfdf7737ac64aad813d91bbfd56bf93)
- File: `smart-turn-v3.2-cpu.onnx`, 8.68 MB on disk
- SHA-256: `2bb026316b14a660486a75b1733cd3fbab8c2fd0314dc9af7be49f8cca967e4f`
- License: [BSD-2-Clause](https://github.com/pipecat-ai/smart-turn/blob/main/LICENSE)

Upstream explicitly supports Chinese and describes an 8 MB quantized CPU model, but its
[official v3.2 CPU benchmark](https://huggingface.co/pipecat-ai/smart-turn-v3/blob/main/benchmarks/smart-turn-v3.2-cpu.md)
reports only 929 Chinese samples: 85.79% accuracy, 0.894 precision, 0.818 recall, 0.854 F1,
4.95% FPR, and 9.26% FNR at the reference decision. Those conversational samples are not
a sermon-domain release set, so upstream's 0.5 threshold is not accepted as a live policy.
The [official usage notes](https://github.com/pipecat-ai/smart-turn) also position Smart
Turn after a lightweight VAD, not as a replacement for all acoustic safety limits.

Reference feature extraction plus ONNX Runtime replayed all 1,136 calibrated endpoints in
38.3 seconds; warm model inference was about 16 ms per call. The probabilities were:

| Acoustic endpoint label | Count | Median completion probability | At least 0.98 |
| --- | ---: | ---: | ---: |
| Hard maximum | 364 | 0.1246 | 1.65% |
| Preferred-maximum pause | 291 | 0.8341 | 11.34% |
| Ordinary trailing silence | 264 | 0.9523 | 26.89% |
| Soft pause after 9 s | 214 | 0.9295 | 18.22% |

No sample reached 0.99. Without human complete/incomplete labels these numbers cannot
choose a safe threshold. Smart Turn therefore remains disconnected from live boundary
authority; the native module is ready for parity tests and future labelled shadow trials.

## Fifty-minute Qwen replay and non-speech guards

The exact Qwen3-ASR 0.6B INT8 stack decoded six clips totaling 3,000.0 seconds. Their
segments came from the calibrated WebRTC developer baseline, so this isolates ASR behavior
and is not an end-to-end replay of the current Swift fallback:

| Source | Audio | Segments | Decode | RTF |
| --- | ---: | ---: | ---: | ---: |
| Argyle 2023 | 300 s | 21 | 73.200 s | 0.2440 |
| Argyle 2025 | 300 s | 22 | 63.000 s | 0.2100 |
| Friendship Mark | 600 s | 41 | 108.558 s | 0.1809 |
| Friendship Nancy | 600 s | 53 | 117.134 s | 0.1952 |
| **First-clip subtotal** | **1,800 s** | **137** | **361.892 s** | **0.2011** |
| Friendship mid-sermon, Mark + Nancy | 1,200 s | 84 | 241.305 s | 0.2011 |
| **Grand total** | **3,000 s** | **221** | **603.197 s** | **0.2011** |

Wall time for the first 30-minute subtotal was 363.261 seconds. The additional clips covered
Mark at 2,400–3,000 seconds and Nancy at 2,100–2,700 seconds, 42 segments each. There is no
aligned verbatim reference, so this is throughput and failure-discovery evidence, not
CER/WER evidence. The local result file is
`.artifacts/sermon-corpus/qwen-mid-sermon-results.json` and remains gitignored.

With a 13-term theological hotword prompt, ten music/non-speech segments echoed the entire
prompt. The new prompt-only repetition guard rejected 10/10. Re-decoding those ten without
hotwords produced five exact `system`/`系统` sentinels, also rejected by the new guard; the
other five contained singing, a short ordinary phrase, or garbled output and are not yet
fully classified. One middle-sermon segment then exposed a mixed case: an ordered theology
prompt prefix followed by valid recognized Chinese. The guard now recursively strips only
an ordered prefix of at least six prompted terms and preserves the remaining speech;
prompt-only output is still rejected. Hotword echo detection is necessary but insufficient.
The locked non-speech set must still determine whether a separate singing/music event gate
is needed; ordinary speech VAD does not promise to distinguish singing from speech.

## Corpus provenance and rights boundary

The local QA sources were the official pages for Argyle's
[2023 Mandarin sermon with bilingual notes](https://arbc.sk.ca/2023/07/09/%e4%bb%8e%e5%a5%b4%e9%9a%b6%e5%88%b0%e5%bc%9f%e5%85%84-from-slave-to-brother/),
[2025 Mandarin sermon with English-translated notes](https://arbc.sk.ca/2025/07/13/living-by-faith-in-an-uncertain-world/),
and Friendship Agape's
[Mandarin/English sermon catalog](https://www.friendshipagape.com/sermons.php). The four
MP3 container durations were 1,490.155, 2,560.052, 4,822.632, and 5,641.752 seconds
respectively; decode/conversion removed container padding, yielding the 14,514.465-second
WAV replay above.

The cited pages make the recordings and translations publicly accessible but do not state
a permissive redistribution license. Consequently, audio, video, notes, extracted text,
and derived transcript are local temporary QA material under `.artifacts` only. They are
gitignored, excluded from App/DMG/release assets, and must never be committed or republished.
Only aggregate, non-reconstructive measurements and case counts belong in this repository.

## Release gates and known limits

Before semantic endpointing or the overall live pipeline may be called production-ready,
the exact release build must pass a manually time-aligned set of at least 12 sermons,
8 hours, and 6 speakers:

| Area | Release gate |
| --- | --- |
| Speech detector | Pinned native libfvad hybrid must pass the locked labelled set; AdaptiveEnergy remains fallback-only |
| Boundary safety | Zero mid-word cuts; unsafe early boundaries at most 0.2% |
| Responsiveness | Endpoint p95 at most 800 ms; at least 98% of final English visible within 3 s |
| Pronouns | Any wrong automatic gender/deity rewrite fails; raw text and audit retained for 100% of corrections |
| ASR input safety | Zero published hotword echoes or known non-speech sentinels; music/noise cases human reviewed |
| Translation fidelity | Zero critical additions, omissions, or changed negation, numbers, names, and Scripture references on the locked set |
| Theology | 100% required-term compliance or an explicitly accepted grammatical variant |
| Stability | 8-hour live soak with no lost transcript entries, bounded memory, and recovery verification |

The current evidence does **not** establish perfect translation, a general pronoun accuracy
rate, semantic endpoint accuracy, CER/WER, an end-to-end 1–3 second SLA, or a completed
8-hour live soak. See [Architecture](Architecture.md) for boundaries and
[Testing](Testing.md) for the full qualification matrix.

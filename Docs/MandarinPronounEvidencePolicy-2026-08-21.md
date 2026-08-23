# Mandarin Pronoun Evidence Policy — 2026-08-21

## Decision

Spoken Mandarin *tā* does not encode the written distinction among `他`, `她`, and
`它`. When the audio and discourse contain no identity evidence, the correct sex is
not recoverable by attention, ASR prompting, or a larger model. Production therefore
uses an evidence-and-abstention policy: preserve the raw Chinese, translate an unresolved
occurrence neutrally, and persist the decision for review. Names, occupations, voice,
and stereotypes are never accepted as gender evidence.

Christian-deity identity is modeled separately from biological male. The ASR glyph `祂`
is not self-authenticating: it remains unresolved without one unique nearby qualified
`神`, `上帝`, `耶稣`, `基督`, `主耶稣`, `我们的主`, `救主`, or `圣灵` anchor. A current-turn
anchor may authorize an audited textual deity correction; bounded prior context may only
classify an already-written `祂` without changing it. Bare `主` is never evidence; bare
`神` requires a lexical boundary and referential continuation.
Competing human/deity anchors abstain, and ordinary compounds such as `车主`, `神父`,
`神经`, `神学`, `精神`, and `门神` do not qualify.

This review triaged 172 results across four workstreams: the linguistic information
boundary, Chinese coreference models, ASR/translation context, and punctuation/speaker
segmentation. Paper, official code, and official model-card sources were preferred.

## Primary evidence

- [Qiu et al., PLOS One 2012](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0036156)
  establishes that spoken Chinese uses one third-person pronunciation while written
  forms mark gender; semantic gender, distance, and working memory affect resolution.
- [Zhan, Levy, and Kehler, PLOS One 2020](https://pmc.ncbi.nlm.nih.gov/articles/PMC7446932/)
  models Mandarin pronoun interpretation as probabilistic inference from discourse
  priors and production likelihood, not deterministic recovery.
- [Grammatical roles and coherence relations, Lingua Sinica 2016](https://link.springer.com/article/10.1186/s40655-016-0011-2)
  shows that syntax, subject bias, and coherence affect referent salience.
- [PROSE, EMNLP 2023](https://aclanthology.org/2023.emnlp-main.141/) and
  [GuoFeng, EMNLP 2022](https://aclanthology.org/2022.emnlp-main.774/)
  provide Chinese-English spoken-document and zero-pronoun research benchmarks;
  neither is a turnkey Apple-native runtime.
- [WMT contrastive pronoun evaluation, 2018](https://aclanthology.org/W18-6307/)
  supports testing pronouns directly because aggregate translation scores can hide
  context-sensitive pronoun failures.

Attention can rank explicitly available antecedents. It cannot distinguish two worlds
that yield the same audio and the same observable discourse. Operationally complete
gender handling requires explicit metadata or human correction; otherwise neutral
English is the only non-guessing output.

## Candidate ranking

1. **Typed evidence + Hy-MT2 guidance and validation — selected.** Zero extra model
   weight, deterministic audit, and safe abstention. It preserves modular provider
   replacement. There is not yet end-to-end SLA evidence, and the current component
   latency measurements do not meet the release threshold.
2. **Hy-MT2 background context — selected as bounded defense in depth.** The existing
   local 1.8B Q4 model follows explicit unresolved/verified guidance, but context alone
   is not evidence.
3. **Qwen3-ASR context/hotwords — glossary only.** The
   [official Qwen3-ASR API](https://github.com/QwenLM/Qwen3-ASR) exposes context, while
   the pinned [sherpa-onnx implementation](https://github.com/k2-fsa/sherpa-onnx/blob/1cb484af5e69d3c7803c1eb0b3b5ab8041e0e911/sherpa-onnx/csrc/offline-recognizer-qwen3-asr-impl.cc)
   injects comma-separated hotwords into its chat template. A held-out sermon test did
   not support using this path for discourse or gender answers.
4. **Chinese-English CT-Transformer punctuation — shadow candidate.** Sherpa documents
   a [72 MB INT8 ONNX model](https://k2-fsa.github.io/sherpa/onnx/punctuation/pretrained_models.html).
   It may improve punctuation/context windows but supplies no gender evidence, and the
   upstream FunASR model license must be approved before distribution.
5. **Speaker diarization — optional boundary signal.** The Apple-native
   [FluidAudio Sortformer](https://github.com/FluidInference/FluidAudio/blob/main/Documentation/Diarization/Sortformer.md)
   can mark speaker changes, but speaker identity is not the gender of a third person
   mentioned in a sermon.
6. **HanLP Chinese coreference — reject for offline release.** The
   [official table](https://hanlp.hankcs.com/demos/cor.html) exposes coreference through
   a service and does not identify a distributable local pretrained coreference artifact.
7. **Research-only Chinese classifiers — reject for now.** The MIT
   [CLUE WSC classifier](https://github.com/ZhiyaoWen999/chinese-coreference-resolution)
   is pair classification without a production checkpoint; the
   [joint end-to-end resolver](https://github.com/cheniison/e2e-joint-coref) requires
   licensed OntoNotes data, an old Python/PyTorch stack, and substantial training.
8. **Maverick, CorPipe, and Chinese CoreNLP — reject.** Available weights are not a
   permissively licensed, compact, Chinese spoken-domain, Apple-native replacement.

## Measured regression results

| Test | Result |
| --- | --- |
| Old production prompt, unresolved ASR `他` | Real Hy-MT2 emitted masculine `He` |
| Explicit unresolved guidance | Real Hy-MT2 emitted singular `They` in 0.301–0.422 s |
| Explicit verified-female guidance | Real Hy-MT2 emitted `She` |
| Explicit verified-deity guidance | Real Hy-MT2 emitted `God … He … His` in 0.296–0.410 s |
| Four Qwen hotword/context variants | 0/4 repaired the held-out object pronoun |
| Qwen prior-turn variant | Echoed prior text; unsafe for the ASR prompt channel |
| Frozen 108-occurrence resolver replay | 1/85 correct automatic, 84/85 safely missed, 0 wrong automatic |
| Verified-entity leave-one-source-out audit | 0 independently supported entities; loose string rule 0/6 correct |

The Qwen test used local, non-redistributable source media. The repository contains only
an environment-gated harness and aggregate measurements, never the audio or transcript.

## Remaining hard cases

- An unresolved occurrence can share a sentence with a separately verified referent.
  Global validation blocks provable contradictions, but exact source-target pronoun
  alignment is needed to reject every same-gender misassignment in a mixed sentence.
- Object pronouns, quotations, multiple plausible people, and evidence introduced only
  after the occurrence remain unresolved by design.
- Punctuation and diarization can bound context; neither creates referent-sex evidence.
- The reader UI now surfaces the persisted unresolved/neutral notice without changing the
  raw transcript. The audit remains durable for later review and correction.

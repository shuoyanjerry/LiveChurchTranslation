# Qwen3-ASR English Qualification — 2026-08-22

## Outcome

The production Qwen3-ASR 0.6B INT8 adapter was exercised with
`ASRRequest.languageCode = "en"` over 18 locally generated theological utterances. The weighted
result passed the deterministic synthetic regression gate:

| Evidence | Result | Gate |
| --- | ---: | ---: |
| Clips / voices / English locales | 18 / 7 / 6 | at least 18 / 6 / 6 |
| Audio | 68.7480625 seconds | informational |
| Word errors / reference words | 2 / 190 | informational |
| Weighted WER | 1.0526% | at most 2% |
| Character errors / reference characters | 6 / 1,039 | informational |
| Weighted CER | 0.5775% | at most 1% |
| Decode time / real-time factor | 13.161132165 seconds / 0.19144 | RTF at most 1.0 |
| Worst clip WER | 10% | at most 10% |

Six additional adversarial clips distinguish prayer, praise, grace, and their inflections. The
two remaining strict-WER mismatches were `Prayer` → `Greer` and `the congregation` →
`a congregation`; 16 clips had zero normalized WER. Reference text was not relaxed and neither
phrase was inserted into the context prompt. This is strong model-wiring and terminology
evidence, but it is not a claim of perfect English recognition or human-sermon accuracy.

## Reproduction

```sh
QWEN_MODEL_DIR="/path/to/qwen3-asr-0.6b-int8-2026-03-25" \
  Scripts/run_qwen_english_qualification.sh
```

The script uses only installed macOS voices, `say`, `afconvert`, `plutil`, and `shasum`. It creates
16 kHz mono PCM16 WAV files and an SHA-256-bound manifest under the gitignored
`.artifacts/qwen-english-qualification` directory, then runs the real production provider. The
report records references, hypotheses, per-clip timing, weighted error counts, host OS, model and
runtime revisions, and the exact generated-manifest hash. Report permissions are `0600`.

Generation is reproducible as a procedure, not guaranteed bit-identical across macOS releases:
Apple may update a voice asset. The manifest therefore records the OS version and every audio
hash. The recorded run used macOS 15.5; its manifest SHA-256 was
`d6ef3af5065ce1989389a93e8f03f8124aea2ba0d81f812d97b8a28e4ab0026a`.

## Production context policy

The runner calls the same `ASRContextTermSelector` and enabled `DefaultGlossary` used by the live
English mode. The production prompt is capped at 18 delimiter-safe terms and contains only
glossary vocabulary, not fixture sentences. It retains prayer, pray, prays, praying, praise,
praises, praising, grace, and gracious. Placing `gracious` last reduced the expanded corpus from
four word errors to two without changing references or adding sentence fragments.

Earlier diagnostics showed why a larger prompt was rejected: the former 48-entry prompt consumed
142 tokenizer tokens and the 30-entry prompt consumed 66, both triggering the runtime's
`max_total_len = 512` warning. The 30-entry lane also emitted a truncated hotword-list
hallucination. The adapter now recognizes English prompt echoes case-insensitively, including a
six-or-more-term contiguous truncated suffix, and retries once without hotwords. Regression tests
cover both complete and truncated English echoes.

## Corpus and scoring policy

All 18 sentences are short, original paraphrases written for this test. They cover salvation,
grace, justification, sanctification, the Holy Spirit, the Trinity, resurrection, church,
repentance, Melchizedek, and eschatology without copying Bible verses or sermon transcripts.
Voices span `en_US`, `en_GB`, `en_AU`, `en_IE`, `en_IN`, and `en_ZA`, with varied speaking rates.

WER lowercases text, removes straight and curly apostrophes, converts remaining punctuation to
word boundaries, and applies strict word-level Levenshtein distance. CER lowercases text, removes
non-alphanumeric characters, and applies strict character-level Levenshtein distance. Aggregate
rates are micro-averaged from total edits and total reference units; they are not an unweighted
mean of clip percentages.

## Private human-sermon rights audit

The local `online-sermon-corpus-manifest.json` declares private, non-commercial product QA as its
default use and forbids public-repository media, transcripts, protected manuscripts, and training
unless an item license expressly permits them. The two Friendship Agape items tagged with
`spoken_human_english` permit private listening/QA but forbid redistribution. Their English is
embedded interpretation with no timecoded or verbatim reference, so computing WER from those
items would be methodologically invalid. No private audio or transcript was copied into the test
target or report.

Before treating English ASR as production-qualified for arbitrary churches, a separate licensed
or consented human-speech set still needs time-aligned verbatim references, multiple speakers,
room reverberation, microphone/PA variation, noise, code-switching, and long-session coverage.
That human evidence remains an explicit qualification gap; synthetic passing results must never
be described as perfection.

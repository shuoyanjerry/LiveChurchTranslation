# English-to-Simplified-Chinese translation qualification — 2026-08-22

## Scope

This lane exercises the production Hy-MT2 1.8B Q4_K_M adapter with English input and
Simplified Chinese output. The 24 short, human-authored fixtures cover salvation, the
Trinity, Christology, baptism, the Lord's Supper, covenant, church order, prayer,
negation, Scripture-reference preservation, and the distinction between citing a
reference and reciting or quoting a passage. They contain no copied Bible passage.

The same real-model test also retains the four Mandarin-to-English theological fixtures
and the discourse-pronoun checks. Run it only with the pinned local artifacts:

```sh
HYMT_MODEL_DIR=/path/to/Hy-MT2-1.8B-Q4_K_M.gguf \
HYMT_LLAMA_SERVER=/path/to/llama-server \
swift test --filter HyMT2RealModelSmokeTests
```

## Result

The final 2026-08-22 run passed all 24 English-to-Simplified-Chinese fixtures and all existing
Mandarin-to-English/pronoun cases. Sentence inference for the English-to-Simplified-Chinese set was
approximately 0.39–1.07 seconds on the observed Apple Silicon host. The accepted output
preserved required theological relationships, negation, Arabic chapter-and-verse
numbers, and Simplified Chinese output. Contextually appropriate `祂` remained intact.

Human inspection was part of this iteration. An earlier keyword-only pass omitted the
meaning that a reference “was cited,” and another output placed “历世历代” unnaturally.
Both were rejected despite the automated pass, converted into relationship-level
translation constraints, and rerun with the real production model. The final examples
included:

- `神立约的应许在历世历代中彰显祂的信实。`
- `我们在圣灵里借着子向父祷告。`
- `哥林多前书 15:3-4 被引用了，没有背诵那段经文。`

## Interpretation and release boundary

This is a deterministic regression and integration lane, not proof of perfect,
infallible, or universally pastoral translation. It does not replace blinded bilingual
review of licensed human sermon audio, nor does it grant permission to bundle or
translate CUNPSS-神 or ESV text. Exact Bible quotations must preserve the licensed source;
generated sermon translation may use `他` or `祂` according to context and church style.

Release evidence is the test source in
`Tests/TranslationHyMT2Tests/EnglishTheologicalGoldenFixtures.swift`,
`EnglishTheologicalExtendedFixtures.swift`, and `HyMT2RealModelSmokeTests.swift`, together
with the pinned model/helper identities. See `ScriptureStandards.md` for the separate
copyright and pastoral-review gates.

# Scripture editions, terminology, and qualification gate

## Product language policy

The production edition contract is fixed to these exact identifiers:

- `esv-2025`: *The Holy Bible, English Standard Version®*, ESV Text Edition: 2025;
- `cunpss-shen-1988-zh-Hans`: `新标点和合本，神版`, 1988, Simplified Chinese
  (`CUNPSS-神`; YouVersion Version ID 48; the Hong Kong Bible Society online source
  identifies this edition as `CUNP1s`).

Chinese output follows the terminology and book names of the selected Simplified Chinese
Shen Edition. English output follows the selected ESV edition. These identifiers describe
the terminology baseline; they do not imply endorsement by either publisher and do not
turn a generated translation into an exact Bible quotation.

For Chinese output:

- use `神`, not `上帝`, for the selected Shen Edition;
- as a product and church-style rule, allow both `他` and `祂` when context makes the
  referent clear; never mechanically replace either glyph in an exact source quotation;
- use Simplified Chinese book names and preserve explicit chapter-and-verse numbers;
- do not reconstruct, complete, or invent verse text that the speaker did not say.

The production glossary contains names and short non-expressive theological terms, not
an offline Bible text. Public test fixtures use original sentences or paraphrases. A
machine-generated translation is a live listening aid and must not be presented as an
authoritative Bible quotation. A local aggregate test may record the declared edition and
source hashes, but that does not authorize runtime quotation, publication, or distribution.
Only an authorized, version-pinned source may be displayed as exact ESV 2025 or
CUNPSS-神 1988 text in a distributed build.

## Local ephemeral test versus distribution

The product does not require a church, denomination, incorporated entity, or commercial
account to run the local ephemeral preflight. A tester may identify as an individual or a
project. The tester supplies files outside the workspace, records exact text/audio source
attribution and intended evaluation use, and independently pins every file and declaration
by SHA-256. The working copy is owner-only and is destroyed after success, failure, or a
termination signal.

This local path is evaluation-only. Its manifest must explicitly prohibit model training
and redistribution. It may allow non-weight model adjustment—hotwords, prompts, glossaries,
decoding, or thresholds—when the tester declares permission for that local use. It never
downloads from ESV.org, YouVersion, API.Bible, or a publisher
API, never commits source text/audio, and emits aggregate metrics rather than reference
text. A tester declaration records provenance and intended use; it is not a license,
publisher authorization, or proof that the source is authentic.

The user's statement that they own or hold permission for the supplied spiritual materials
may be stored as the hashed local source/use declaration. The product records that claim as
provenance; it does not present it as publisher endorsement or permission to redistribute.

The distinction does not expand publisher terms. Crossway's ordinary policy expressly
disallows translating ESV text into another language without permission. Therefore an
exact-verse ESV-to-Chinese lane without rights-holder permission may be used only as the
tester's private experiment; it must not be described as compliant, published, shared, or
used to support a release claim. Playback access likewise does not establish text or
narration rights.

Before enabling exact verse retrieval, bundling publisher text/audio, runtime quotation,
exports, or public/shared evaluation results, obtain the appropriate text and narration
permissions directly from their rights holders. No church authorization is involved; the
relevant permission is from the content or recording rights holder. Terminology alignment,
book-name mapping, and generated listening-aid output may ship without embedding Bible
text.

The optional rights-holder request checklist is in
[ScriptureLicensing.md](ScriptureLicensing.md). It is not a prerequisite for local
ASR-only ephemeral preflight and is never a request for church authorization.

## Primary references

- [Hong Kong Bible Society: Simplified Chinese Bible publications](https://www.hkbs.org.hk/zh-cn/7)
- [Hong Kong Bible Society online Bible](https://rcuv.hkbs.org.hk/CUNP1s/GEN/1/)
- [CUNPSS-神 authorized platform identity, Version ID 48](https://www.bible.com/versions/48-cunpss-%E7%A5%9E-%E6%96%B0%E6%A0%87%E7%82%B9%E5%92%8C%E5%90%88%E6%9C%AC-%E7%A5%9E%E7%89%88)
- [Crossway: ESV Bible translation update](https://www.crossway.org/articles/esv-bible-translation-update/)
- [Crossway ESV permissions](https://www.esv.org/churches/permissions/)
- [Crossway digital permissions request](https://www.crossway.org/permissions/digital/)
- [Crossway audio permissions request](https://www.crossway.org/permissions/audio/)
- [ESV API terms and access](https://api.esv.org/)
- [API.Bible AI licensing restrictions](https://care.api.bible/article/405-express-licensing-faqs)

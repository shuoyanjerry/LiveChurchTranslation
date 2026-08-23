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
  referent clear; never mechanically replace either glyph in an exact licensed quotation;
- use Simplified Chinese book names and preserve explicit chapter-and-verse numbers;
- do not reconstruct, complete, or invent verse text that the speaker did not say.

The production glossary contains names and short non-expressive theological terms, not
an offline Bible text. Public test fixtures use original sentences or paraphrases. A
machine-generated translation is a live listening aid and must not be presented as an
authoritative Bible quotation. Only a version-pinned licensed source whose file and grant
hashes passed the private qualification gate may be labeled as exact ESV 2025 or
CUNPSS-神 1988 text.

## Rights and qualification gate

Neither CUNPSS-神 nor ESV full text or audio may be bundled, downloaded, cached as a
corpus, used as a hidden retrieval source, or copied into test fixtures until the text and
recording rights holders have approved the exact ASR and translation uses in writing.
Internal, free, or church-only distribution does not create an exception to those grants.

Before enabling verse retrieval or distributing publisher text:

1. Obtain Hong Kong Bible Society permission covering the CUNPSS-神 1988 digital master,
   ASR evaluation, bilingual alignment, translation evaluation, local caching, runtime
   display, exports, and the intended territories. The public
   contact is [info@hkbs.org.hk](mailto:info@hkbs.org.hk); the
   [Digital Bible Library](https://library.bible/) is an additional licensed-content
   route for eligible organizations.
2. Obtain Crossway digital and audio permission covering ESV Text Edition: 2025,
   transcription/WER evaluation, bilingual alignment, and this product's
   English-to-Chinese workflow. The standard ESV API and quotation policy are not a
   substitute: ordinary terms restrict caching and expressly disallow translating ESV
   into another language without permission.
3. Obtain a separate recording grant from the producer of each Chinese or English
   narration. Permission to display Bible text does not automatically license its audio
   for speech-to-text evaluation, segmentation, or model adaptation.
4. Record signed grants, approved copyright notices, territories, versions, expiry,
   allowed AI purposes, reporting duties, and revocation procedures in the private
   evidence set. Bind every grant, transcript, and audio file by SHA-256.
5. Have bilingual pastoral reviewers approve semantic faithfulness and Scripture-reference
   preservation. Exact-string scores alone are not sufficient translation evidence.

No release may claim ESV/CUNPSS Scripture-reading optimization while a required text,
audio, ASR-evaluation, or cross-language-evaluation grant is missing. Terminology
alignment and book-name mapping may ship without embedding copyrighted text.

The request checklist and draft language are in
[ScriptureLicensing.md](ScriptureLicensing.md). Licensed files remain outside Git and are
admitted only through the private qualification preflight.

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

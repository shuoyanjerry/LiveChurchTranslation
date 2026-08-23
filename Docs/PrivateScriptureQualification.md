# Private Scripture qualification

This lane accepts an already licensed bilingual reading corpus. It never downloads,
scrapes, supplies, or redistributes Bible text or narration. Passing preflight means the
declared edition metadata, rights evidence, and source files are present, private, and
hash-bound; it is not proof that their contents are authentic and is not a substitute for
legal review of the grant itself.

Preflight does not decode audio, compare a recording with its reference, authenticate a
publisher master, or determine whether an evidence document legally grants the declared
rights. The named authorization reviewer must verify those facts before freezing the
manifest hash. ASR and translation runners perform the separate content/quality checks.

## Fixed contract

Schema V1 accepts only the complete `ScriptureEditionPair.production` value:

- `esv-2025`: *The Holy Bible, English Standard Version®*, `ESV Text Edition: 2025`;
- `cunpss-shen-1988-zh-Hans`: `新标点和合本，神版`, 1988 Simplified Chinese,
  official online identifier `CUNP1s`.

These identifiers have two distinct uses. `terminologyBaseline` guides book names and
terms but never labels generated prose as a quotation. `exactQuotation` requires the
private source, edition, rights, and hashes to pass this gate. Exact Chinese source text
must preserve its licensed glyphs, including `他` or `祂` as supplied.

## Private directory

Prepare a directory outside Git with this shape. Names are illustrative; paths in the
manifest are relative to the corpus root.

```text
manifest.json
evidence/english-text-or-audio-grant.pdf
evidence/chinese-text-or-audio-grant.pdf
audio/<one file per item>
reference/<one UTF-8 file per item>
```

Do not put credentials in the manifest. Every directory is changed to mode `0700` and
every file to `0600` during import. Symlinks, special files, empty files, traversal,
files outside the root, hash drift, and files over the fixed limits are rejected.

## Manifest V1

The top-level keys are `schemaVersion`, `corpusID`, `createdAt`, `visibility`,
`mustNotCommit`, `editionPair`, `grants`, `items`, and `translationPairs`. Unknown and
duplicate JSON keys are rejected. Use:

```json
{
  "schemaVersion": 1,
  "visibility": "gitignored-private-local-qa-only",
  "mustNotCommit": true
}
```

The actual manifest also needs the remaining keys and the complete encoded production
edition pair. Generate it with the public Swift models instead of hand-copying edition
descriptors, so any field drift fails closed.

Each grant records a stable ID, exact `editionID`, licensor, licensee, agreement ID,
territories, validity dates, reviewer and review date, plus a regular evidence file and
its SHA-256. All grants must name the same licensee. Its `rights` object contains these
required Boolean declarations:

```text
textUseAuthorized
audioUseAuthorized
recordingUseAuthorized
asrEvaluationAuthorized
crossLanguageEvaluationAuthorized
modelTrainingAuthorized
redistributionAuthorized
```

An item has separate `textGrantID` and `audioGrantID`; one agreement may fill both roles.
The text grant must authorize text use and cross-language evaluation. The audio grant
must authorize audio use, recording use, and ASR evaluation. Training and redistribution
flags are recorded but are never inferred: this tool performs qualification only.

Every item is `exactQuotation`, carries audio/reference SHA-256 values, language and
edition IDs, a canonical OSIS book ID, verse range, speaker/environment metadata,
`readingKind` (`fullVerse`, `partialVerse`, or `referenceOnly`), and `partition`.
Translation pairs must align the same passage, reading kind, and partition in the fixed
English-to-Simplified-Chinese direction. Every item belongs to exactly one pair. Both
`development` and `sealedBlindQualification` partitions are mandatory, preventing a
tuned development set from certifying itself.

## Import and preflight

After an authorized reviewer freezes `manifest.json`, obtain its SHA-256 independently
and keep that expected value outside the corpus. Import never trusts a hash declared by
the same manifest:

```bash
Scripts/import_licensed_scripture_corpus.sh \
  /absolute/path/to/prepared-corpus \
  church-scripture-2026q3 \
  <independently-reviewed-64-character-manifest-sha256>
```

The script stages the files below the gitignored
`.artifacts/scripture-qualification/` boundary and runs:

```bash
swift run scripture-qualification-tool verify \
  <private-corpus-root> <manifest.json> <expected-manifest-sha256>
```

The loader returns verified audio/reference URLs for an authorized runner, plus safe
source-identity evidence containing only IDs, verse metadata, partitions, and hashes.
It never returns reference text as a report field. `ScripturePunctuationFidelityMetric`
compares Unicode punctuation and its lexical position independently of the existing
punctuation-stripping CER, returning counts and rates only.

# ASRQualificationManifestToolTests

## Purpose

This independent, test-only target freezes the six-clip public-domain Mandarin Scripture qualification corpus as strict `ASRQualificationManifestV2`. It does not run an ASR model and does not depend on either provider harness.

The env-gated test selects exactly `webrtcStable`, joins files by the `.wav` filename stem rather than VAD `corpusID`, requires the corpus and reference manifests to agree exactly, verifies all 220 source ranges and model-PCM hashes, and writes only after every check succeeds.

## Replay command

```sh
mkdir -p .artifacts/asr-qualification
ASR_QUALIFICATION_VAD_REPORT="$PWD/.artifacts/vad-benchmarks/public-spiritual-webrtc-stable-v1.json" \
ASR_QUALIFICATION_CORPUS_MANIFEST="/Users/shuoyan/church_translation/data/evaluation/public_spiritual_corpus_v1/corpus.json" \
ASR_QUALIFICATION_REFERENCE_MANIFEST="/Users/shuoyan/church_translation/data/evaluation/runs/qwen3-asr-06b-q8-zh.manifest.json" \
ASR_QUALIFICATION_WAV_DIR="$PWD/.artifacts/public-spiritual-wav-v1" \
ASR_QUALIFICATION_OUTPUT="$PWD/.artifacts/asr-qualification/public-domain-mandarin-scripture-v2.json" \
swift test --filter ASRQualificationManifestToolRunTests.freezeConfiguredManifestV2
```

With none of the five variables set, the gated test returns without writing. Supplying any variable makes all five mandatory; blank values are treated as missing.

## Frozen provenance

- Three source-manifest hashes cover the exact raw input bytes.
- VAD configuration SHA-256 covers compact UTF-8 JSON produced by `JSONEncoder` with recursively sorted keys and no trailing newline.
- `generatorRevision` is the VAD report's repository revision, with `+dirty` appended when its environment records uncommitted changes.
- `referenceSHA256` covers exact decoded `reference_text` UTF-8, without trimming or Unicode normalization.
- `allowsHypothesisEdgeInsertions` copies `asr_ignore_hypothesis_edges`, so scoring policy is available without reopening the reference manifest.

## Failures

Unknown or missing JSON fields, wrong schema/type, duplicate IDs, corpus or clip-set drift, reference mismatch, unsafe filenames, nonzero VAD padding, noncontinuous sequence, invalid absolute ranges, source byte-count/hash/metadata drift, and PCM hash mismatch all fail closed. No range is clamped or skipped. The output parent must already exist, and the final JSON is written using Foundation's atomic replacement only after all clips pass.

## Tests

Unit fixtures exercise strict shape rejection, source joining independent of array order, duplicate/set/text/padding failures, canonical provenance, scoring-policy copying, complete WAV replay, and preservation of a preexisting output when verification fails. Tiny synthesized WAVs are used; no model is loaded.

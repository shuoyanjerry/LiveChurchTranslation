# ASRQualificationSupport

## Purpose

`ASRQualificationSupport` is a provider-neutral, evaluation-only module for freezing and replaying exact ASR inputs. It does not import an ASR provider, a VAD implementation, a model runtime, or either existing Qwen/Fun-ASR qualification harness.

Manifest V2 is deliberately fail-closed. It records corpus and upstream provenance, immutable source-audio identity, reference-text identity, absolute source ranges, boundary reasons, padding, and the exact PCM identity presented to a model.

## API

- `ASRQualificationManifestV2`, `ASRQualificationProvenanceV2`, `ASRQualificationClipV2`, and `ASRQualificationSegmentV2` are immutable `Codable`, `Equatable`, and `Sendable` values.
- `ASRQualificationManifestDecoder` accepts `Data` or a file URL. It rejects unknown, missing, and incorrectly typed JSON fields, then runs the semantic validator.
- `ASRQualificationManifestValidator` performs the same semantic checks on values built in memory.
- `ASRQualificationManifestFactory.make(corpusID:provenance:clips:)` is a pure producer-side helper. It fixes `schemaVersion` to `2` and returns only a validated manifest.
- `ASRQualificationWAVLoader.load(clip:from:)` verifies a source WAV and returns immutable `ASRQualificationLoadedSegment` values whose `samples` can be passed directly to an ASR provider.
- `ASRQualificationTextMetrics.normalizedEnglishWER` provides strict micro-aggregatable English
  word-error evidence. It lowercases, removes apostrophes, maps other punctuation to word
  boundaries, and exposes edit and reference-word counts alongside the rate.

JSON field names are the exact camel-case Swift property names. Unknown fields are errors at the manifest, provenance, clip, and segment levels. Duplicate keys in any JSON object are rejected before Foundation decoding, including keys whose escape sequences decode to the same string.

## Frozen Semantics

- Clip IDs are nonblank and unique. Each clip must contain segments in their frozen array order with exactly 1-based contiguous `sequence` values.
- Both `startSample` and `endSample` must strictly increase between adjacent segments. Pre-roll overlap remains valid: a later `startSample` may be below the preceding `endSample`.
- `[startSample, endSample)` is the absolute valid range in the source WAV. It is never clamped, reordered, or skipped. It must satisfy `0 <= start < end <= totalSamples` and `validSampleCount == endSample - startSample`.
- `syntheticPaddingSamples` is not part of the source range. The loader reads exactly `validSampleCount` source samples and appends that many Float32 zero samples. Loaded length is `validSampleCount + syntheticPaddingSamples`.
- `syntheticPaddingSamples` is capped at 320,000 samples (20 seconds at 16 kHz). Loaded PCM is capped at 1,920,000 samples per segment (120 seconds and about 7.3 MiB at 16 kHz) and 16,000,000 samples across one clip (about 61 MiB). The frozen corpus maximum is 8,465,920 loaded samples in one clip. Every per-segment and cumulative addition is overflow-safe and validated before source decoding or array allocation.
- `audioSHA256` hashes every raw byte of the source WAV.
- `referenceSHA256` hashes the raw UTF-8 bytes of the original `referenceText` in the reference manifest. Producers must not trim, normalize Unicode, change newlines, or otherwise rewrite the text before hashing.
- `allowsHypothesisEdgeInsertions` freezes the reference manifest's `asr_ignore_hypothesis_edges` scoring policy for provider-neutral replay.
- `pcmSHA256` hashes the exact model input as canonical little-endian Float32 bytes, including appended zero padding.
- Every SHA is canonical lowercase 64-character hexadecimal. Provenance also requires nonblank VAD strategy and generator revision strings.

The WAV loader accepts uncompressed mono PCM16 and IEEE Float32 RIFF/WAVE, including `WAVE_FORMAT_EXTENSIBLE` PCM subformats. PCM16 is divided by 32,768 to obtain model Float32 values. NaN and positive or negative infinity in loaded Float32 PCM are rejected before model-PCM hashing and before any segment is returned. It never resamples or mixes channels.

## Dependencies

Only Swift, Foundation, and CryptoKit are used. The target has no package-target dependency and no model SDK dependency.

## Threading

The decoder, validator, and WAV loader are stateless `Sendable` values with synchronous methods. Separate calls can run concurrently. A load call owns its mapped source data and exposes no shared file handle or mutable cache.

## Failures

All policy and integrity failures use `ASRQualificationError`. Categories cover manifest reads and shape, duplicate or unknown JSON fields, schema/provenance, empty or duplicate identities, sequence/order/range/accounting and resource-limit errors, WAV format/read failures, non-finite Float32 PCM, whole-file audio hash mismatch, sample-rate or sample-count mismatch, short segment reads, and exact model-PCM hash mismatch. I/O or integrity failures never produce a partial segment list.

## Tests

`ASRQualificationSupportTests` covers Codable round trips, strict unknown- and duplicate-field rejection at every nesting level, escaped-equivalent duplicate keys, required fields, schema and provenance checks, lowercase hashes, unique IDs, 1-based sequence continuity, strictly increasing absolute boundaries with allowed overlap, range and padding accounting, overflow and allocation limits, finite Float32/PCM16/extensible WAV decoding, NaN/infinity rejection, synthetic zero padding, whole-file/metadata/PCM mismatch, unsupported stereo/malformed WAV, unreadable files, and explicit no-clamping behavior. Tests synthesize tiny WAVs and never run a model.

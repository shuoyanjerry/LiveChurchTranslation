# ASRQwen3Tests

## Purpose

This target tests the production Qwen3-ASR adapter and owns its environment-gated,
provider-neutral qualification lane. The lane replays every absolute segment in the frozen
Manifest V2 and emits shared Report V3. It does not create boundaries or reinterpret cumulative
timestamps.

## Public test boundary

The harness accepts exactly these required environment variables:

- `QWEN_MODEL_DIR`
- `MANDARIN_ASR_QUALIFICATION_MANIFEST`
- `MANDARIN_ASR_REFERENCE_MANIFEST`
- `MANDARIN_ASR_WAV_DIR`
- `QWEN_ASR_REPORT`

`QWEN_QUALIFICATION_PROFILE` is optional. When absent, the existing `baseline2` configuration is
used. Its only accepted values are `threads4` and `threads6`; every other value fails closed.
Direct thread-count, partial-clip, and prompt overrides are rejected.

The optional `QWEN_ASR_BACKGROUND_LOAD_NOTE` can replace the conservative default timing caveat.
There is no partial-clip or legacy boundary-manifest option.

## Dependencies

The harness depends on `ASRQualificationSupport`, `ASRAPI`, `ASRQwen3`, and `VADAPI`. Model
inference remains inside the production `Qwen3ASRProvider`; source WAV parsing, PCM verification,
metrics, and Report V3 construction remain in the provider-neutral support module. Every Report V3
records the selected profile, thread count, glossary prompt, decoder limits, sampling settings,
compute provider, runtime revision, and six-file model-integrity policy.

## Threading model

The environment-gated run is sequential. A single Qwen provider actor loads one verified model,
then receives all 220 manifest segments in order. Every call, including the bounded prompt-echo
fallback, is timed through success or failure. The baseline uses two inference threads; the only
experimental profiles use four or six. No Qwen and FunASR qualification models should run
concurrently.

## Failure modes

The run fails closed on a changed qualification manifest, changed reference-manifest bytes,
missing or changed model artifact, unsafe clip ID, WAV identity mismatch, PCM mismatch, unknown VAD
end reason, or invalid Report V3 input. Provider failures become stable redacted attempt codes and
remain in the three-second SLA denominator. The report explicitly labels background load as
uncontrolled unless the operator supplies a more specific honest note.

## Tests

Unit tests cover required inputs, bounded profiles, rejected overrides, prompt-echo retry policy,
reference provenance, all end-reason mappings, absolute sample timelines, model file byte/SHA
verification, redacted failure codes, and Report V3 wiring. Real model tests are disabled unless
all required environment variables are present.

## English regression lane

`Scripts/run_qwen_english_qualification.sh` generates 18 original, non-Scripture theological
utterances with seven installed macOS voices across six English locales. It runs the production
provider with `languageCode = "en"`, emits a SHA-bound local report, and gates micro-averaged WER,
CER, per-clip WER, and real-time factor. The runner imports the live English-mode context selector
and enabled default glossary, so the recorded prompt is production-identical. Generated WAVs and
reports stay under `.artifacts` and are not repository fixtures. This clean synthetic lane detects
model, language-option, vocabulary, and scoring regressions; it does not replace licensed,
verbatim human-sermon qualification.

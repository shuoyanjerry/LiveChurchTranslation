# Optional Scripture rights-holder request guide

This guide is for requesting permission from a Bible text or narration rights holder. It
is not church or denominational authorization, and it is not a prerequisite for the local
ASR-only ephemeral preflight documented in `PrivateScriptureQualification.md`.

Use it before distributing publisher text/audio, enabling exact verse retrieval or runtime
quotation, publishing exact-verse bilingual results, or making a compliance claim. Do not
attach Bible text or audio to an issue, pull request, or public email thread.

## Information a requester may supply

- requester name, which may be an individual, project, nonprofit, or organization;
- contact email and the intended number of local devices/users;
- whether text, translations, recordings, reports, or exports would be retained;
- whether the request is evaluation-only, runtime display, distribution, prompt use, or
  model training;
- requested duration and deletion/revocation procedure.

No legal church name, church representative, denomination, commercial registration, or
ministry status is required by this project's local test schema. A rights holder may still
ask for additional information when considering an optional permission request.

## Crossway request

The official [digital permission form](https://www.crossway.org/permissions/digital/) and
[audio permission form](https://www.crossway.org/permissions/audio/) are the relevant
publisher channels. Name **ESV Text Edition: 2025** and describe the exact requested uses:

- authoritative text and narration identity;
- temporary local storage and deletion;
- segmentation, speech-to-text, WER/CER, and regression evaluation;
- ESV-to-Chinese bilingual alignment or translation evaluation;
- any runtime display, export, publication, or distribution;
- separate permission for prompt inclusion, retrieval, training, or fine-tuning;
- required copyright notice, attribution, device/user limits, expiry, and reporting.

Crossway's standard policy expressly restricts translating ESV into another language, so
an exact ESV-to-Chinese workflow must not be described as authorized or compliant without
the rights holder's explicit permission.

## Hong Kong Bible Society request

The public contact is [info@hkbs.org.hk](mailto:info@hkbs.org.hk). Name the edition exactly
as **1988 新标点和合本，神版，简体中文 (`CUNPSS-神`, `CUNP1s`)** and describe:

- the authoritative digital master and version identifier;
- temporary local comparison, punctuation/character fidelity, and reference alignment;
- use as a Chinese reference for bilingual evaluation;
- any runtime display, retrieval, export, publication, or distribution;
- separate permission for prompt inclusion, training, or fine-tuning;
- required attribution, limits, expiry, deletion, and reporting.

## Narration source

Text access does not establish permission for a particular recording. Identify the
narrator/producer in `sourceAttribution`. Playback access is not proof that automated
download, segmentation, transcription, repeated evaluation, or redistribution is allowed.
The project does not scrape YouVersion or other playback services.

## Engineering boundary

The local V2 manifest records tester-provided provenance and intended use. It requires
exact edition IDs, text/audio attribution, source/declaration hashes, private containment,
and explicit no-training/no-redistribution values. It does not verify legal authenticity
or replace a publisher license.

A user's statement that they own or have permission for the supplied materials may serve
as the hashed local declaration. `modelAdjustmentAllowed` covers hotwords, prompts,
glossaries, decoding, and thresholds only; it does not authorize fine-tuning or any model
weight update.

If optional publisher permission is later obtained, keep that evidence and all approved
text/audio outside Git. Distribution and exact-quotation features need a separate product
review; passing the ephemeral preflight alone cannot enable them.

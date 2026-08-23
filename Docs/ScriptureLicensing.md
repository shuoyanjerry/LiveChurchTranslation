# Scripture licensing request packet

This project must receive written permission before importing ESV 2025 or
CUNPSS-神 1988 text/audio into the private Scripture qualification lane. Church-only,
free, and local use do not replace the required grants. Do not attach Bible text or
audio to an issue, pull request, or public email thread.

## Information the church must supply

- legal organization and ministry name;
- authorized representative, address, email, and telephone;
- expected number of Macs, listeners, churches, and countries;
- whether transcripts, translations, recordings, or reports may be retained/exported;
- whether the request covers evaluation only, prompt/hotword adaptation, fine-tuning,
  or all three;
- requested term and deletion/revocation procedure.

## Crossway request

Submit both the [digital permission form](https://www.crossway.org/permissions/digital/)
and [audio permission form](https://www.crossway.org/permissions/audio/), and copy
`licensing@crossway.org`. The request must name **ESV Text Edition: 2025** and ask for:

- an authoritative 2025 digital text and corresponding audio identity;
- local storage of the approved text/audio in an internal church application;
- audio segmentation, speech-to-text, alignment, WER/CER, and regression evaluation;
- non-training prompt, hotword, glossary, and decoder adaptation;
- ESV-to-CUNPSS-神 bilingual alignment and Chinese translation evaluation;
- real-time local-network display plus transcript/translation/recording retention;
- separate, explicit permission before any model training or fine-tuning;
- approved copyright notice, territories, device/user limits, expiry, reporting,
  updates, and deletion obligations.

Suggested subject:

> Permission request — internal church ASR and ESV 2025 translation evaluation

Suggested opening:

> [Organization] requests a written license to use the ESV Text Edition: 2025 and an
> approved ESV narration in a local-only macOS accessibility application. The application
> transcribes live English speech and provides a Simplified Chinese listening aid. We will
> not redistribute Bible files or train a model unless the signed grant explicitly permits
> that use. The attached schedule defines devices, territories, retention, evaluation,
> security, attribution, updates, and deletion.

## Hong Kong Bible Society request

Send the organization request to [info@hkbs.org.hk](mailto:info@hkbs.org.hk). Name the
edition exactly as **1988 新标点和合本，神版，简体中文 (`CUNPSS-神`)** and ask for:

- the authoritative digital master and publisher-controlled version identifier;
- local storage, automated comparison, punctuation/character fidelity evaluation,
  Scripture-reference alignment, and bilingual pastoral review;
- use as the Chinese target reference for ESV-to-Chinese evaluation and as the Chinese
  source for Chinese-to-English evaluation;
- runtime display, transcript/translation export, and meeting-record retention;
- separate, explicit permission before prompt inclusion, retrieval, training, or
  fine-tuning;
- approved copyright notice, territories, device/user limits, expiry, reporting,
  updates, and deletion obligations.

Suggested subject:

> 申请授权：1988 新标点和合本神版用于教会内部语音识别与双语评测

Suggested opening:

> [机构名称] 申请书面授权，在仅供教会内部使用的 macOS 无障碍辅助软件中，使用
> 1988 新标点和合本神版（简体）权威数字文本。用途包括经授权朗读的语音转写评测、
> 标点和字形校验、与 ESV 2025 的双语对齐及翻译评测、局域网实时显示，以及经批准的
> 听抄稿和会议记录留存。除非书面授权明确许可，我们不会公开传播经文文件，也不会
> 将正文用于模型训练或微调。

## Narration rights

Text permission does not grant recording rights. The signed schedule must identify the
specific narrator/producer and allow local download, segmentation, transcription,
alignment, repeated automated evaluation, and retention. For the Simplified Chinese
audio shown by YouVersion, the identified producer is 好牧人网站; contact
`haomuren316@gmail.com`. Do not scrape YouVersion or treat playback access as an ASR
license.

## Evidence returned to engineering

After approval, place—not commit—the following files under the private path documented in
`PrivateScriptureQualification.md`:

- signed text grants and separate audio grants;
- authoritative edition/version statement from each rights holder;
- approved text/audio files and their SHA-256 values;
- a machine-readable manifest mapping every clip to book/chapter/verse metadata;
- expiry, territories, allowed purposes, and a contact for revocation;
- a pastoral-review attestation for the sealed blind test set.

Engineering will not activate the corpus from an email summary alone. The preflight must
verify the signed evidence, exact production edition IDs, allowed purposes, file
containment, and SHA-256 identity before a model sees any input.

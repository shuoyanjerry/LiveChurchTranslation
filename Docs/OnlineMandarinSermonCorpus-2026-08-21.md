# Online Mandarin Sermon QA Corpus

Date: 2026-08-21
Updated: 2026-08-23

## Outcome

Eight Exa research workflows have now reviewed 690 returned result slots. The first six workflows reviewed 578 slots and produced 208 exact-string unique URLs after cross-workflow deduplication. The GRN/public-domain extension requested 80 more slots: 52 were returned and reviewed, while 28 failed with Exa HTTP 402 after the search credit limit was reached. A release-focused extension then reviewed 60 results from official Mandarin church archives. Failed slots are not counted as reviewed, and neither extension was folded into the earlier unique-URL count.

The private, gitignored QA corpus contains 18 downloaded items: 12 real-sermon recordings from 11 named speakers (four female, seven male), five GRN scripted programs, and one LibriVox public-domain scripture-reading section. Source-container duration is 52,147.996799 seconds (14.486 hours). The genuine-sermon stratum is 37,524.884495 declared seconds (10.424 hours); the exact decoded 16 kHz PCM value is 37,524.487375 seconds. The 2026-08-23 extension added four genuine sermons and 10,957.357495 declared seconds (3.044 hours).

The repository does not contain downloaded media, captions, transcripts, or protected manuscripts. The machine-readable private manifest is `.artifacts/sermon-corpus/online-sermon-corpus-manifest.json`; its public v1 contract is [`OnlineSermonCorpusManifest.schema.json`](OnlineSermonCorpusManifest.schema.json).

## Research Method

The eight workflows covered:

1. Official churches in Greater China, Singapore, and Malaysia.
2. Official Chinese-diaspora churches in North America, Europe, and Australia.
3. Publisher-provided multilingual captions and bilingual services.
4. Official direct MP3, M4A, PDF, DOCX, and Drive downloads.
5. Copyright, item-specific license, robots, and platform terms.
6. Coverage gaps: female voices, regional Mandarin, joint services, music, low-bitrate audio, and long-running sessions.
7. Official GRN Mandarin program/audio/script pairs plus clearly marked Creative Commons and public-domain material.
8. Release-gate gaps in official North American Mandarin sermon archives, emphasizing independent speakers, long-form church PA audio, and direct first-party media.

Candidates were kept only when the church, ministry, or copyright holder was the primary source. A download button, a crawlable path, or a public Drive link was not treated as permission to redistribute or train on the content.

The extension used Exa for discovery and cross-checking, then verified canonical GRN, LibriVox, Internet Archive, Creative Commons, and provider-policy pages. Where GRN rejected command-line page fetching, a text-only reader fetched the official page content; the manifest retains the canonical GRN URL, the acquisition note, the local snapshot path, and its SHA-256. This fallback was used only for page capture, never to discover or acquire media.

## Downloaded Private QA Set

| Source | Speaker and measured duration | Reference | Conservative use boundary |
|---|---|---|---|
| [Argyle Road Baptist Church](https://arbc.sk.ca/2025/07/13/living-by-faith-in-an-uncertain-world/) | Rebecca Zhang, female, 42:40 | [Human bilingual full manuscript](https://arbc.sk.ca/wp-content/uploads/2025/07/living-by-faith-in-an-uncertain-world.pdf), paragraph-aligned but not timecoded | Private QA only; no open reuse license found |
| [Argyle Road Baptist Church](https://arbc.sk.ca/2023/07/09/%e4%bb%8e%e5%a5%b4%e9%9a%b6%e5%88%b0%e5%bc%9f%e5%85%84-from-slave-to-brother/) | Rebecca Zhang, female, 24:50 | Human bilingual sermon notes with omissions, not a verbatim transcript | Private QA only; no open reuse license found |
| [Friendship Agape Church](https://www.friendshipagape.com/sermons.php) | Nancy Ou, female, 1:20:23 | Human spoken English interpretation in the official audio | Private listening and QA only; no redistribution or training |
| [Friendship Agape Church](https://www.friendshipagape.com/sermons.php) | Caleb Qian, male, 1:28:07 | Human spoken English interpretation in the official audio | Private listening and QA only; no redistribution or training |
| [ECBC Mandarin](https://ecbchurch.org/mandarin/sermons/2023%e5%b9%b43%e6%9c%885%e6%97%a5-%e7%9b%b8%e4%bf%a1%e5%b0%b1%e6%98%af%e6%8a%95%e9%99%8d/) | 钟亦乔姐妹, female, 26:30 | None | Official Save Audio source; private QA only |
| [Living Spring Chinese Christian Church](https://mail.livingspring.efca.org.au/index.php/zh-tw/sermons-tw/mandarinsermon-tw) | 刘卢秀玲姊妹, female, 45:21 | None | Official listen source; private QA only |
| [West Los Angeles Chinese Baptist Church](https://www.wlacbc.org/Chi/multimedia-archive/2-8-2026-%e5%9c%8b%e7%b2%b5%e8%aa%9e%e8%81%af%e5%90%88%e5%b4%87%e6%8b%9c-%e3%80%8c%e4%ba%8b%e5%a5%89%e4%b8%bb%e7%9a%84%e4%ba%ba%e8%a6%81%e5%bc%b7%e5%89%9b%e8%b5%b7%e4%be%86%e3%80%8d/) | 陈浩强牧师, male, 1:06:32 | None | Official Download MP3 source; private QA only |
| [Richmond Emmanuel Church](https://remchurch.org/index.php/sundays/sermon-audio/sermon/6370-2026-02-15-19-07-53) | 王建国牧师, male, 1:08:25 | Chinese topic summary, not a transcript | Official download, All Rights Reserved; private QA only |
| [Vancouver Chinese Alliance Church](https://www.vcac.ca/mandarin/archives/sermons/) | 顾永杰牧师, male, 37:51.216 | None | Official direct audio; private listening and QA only |
| [Vancouver Chinese Alliance Church](https://www.vcac.ca/mandarin/archives/sermons/) | 唐福文牧师, male, 39:51.745 | None | Official direct audio; private listening and QA only |
| [Ann Arbor Chinese Christian Church](http://www.aaccc.org/%e7%9c%9f%e5%af%a6%e7%9a%84%e6%95%ac%e6%8b%9c-the-real-worship/) | 王牧师, male, 53:46.680 | None | Official direct audio; private listening and QA only |
| [ECBC Mandarin](https://ecbchurch.org/mandarin/sermons/2026%e5%b9%b45%e6%9c%883%e6%97%a5-%e6%81%a9%e5%8f%ac/) | 聂书全牧师, male, 51:07.716 | None | Official Save Audio source; private listening and QA only |
| [GRN Words of Life 1](https://globalrecordings.net/en/program/29260) | Unnamed Mandarin narrator(s), 40:47 | Approved English source guides for four spoken tracks; adaptation guides, not verbatim translations | Item notice permits unmodified copying for personal/local ministry use; no sale or bundling |
| [GRN Good News — Female](https://globalrecordings.net/en/program/64259) | Unnamed female voice, 40 MP3s, 48:29.309 | Official [zh-Hans](https://globalrecordings.net/en/script/zh-Hans/395) and [English](https://globalrecordings.net/en/script/en/395) variants; adaptation guides, not verbatim or timecoded | Audio item notice: unmodified personal/local-ministry copying; no sale/bundling; broader use needs permission |
| [GRN Good News for university students](https://globalrecordings.net/en/program/62908) | Unnamed voice, 40 MP3s, 37:03.438 | Official [zh-Hans](https://globalrecordings.net/en/script/zh-Hans/394) and [English](https://globalrecordings.net/en/script/en/394) variants; adaptation guides, not verbatim or timecoded | Same program-specific audio boundary; no training or repository redistribution |
| [GRN Look, Listen & Live 1](https://globalrecordings.net/en/program/80921) | Unnamed voice, 24 MP3s, 31:02.713 | Official [zh-Hans](https://globalrecordings.net/en/script/zh-Hans/418) and [English](https://globalrecordings.net/en/script/en/418) variants; adaptation guides, not verbatim or timecoded | Same program-specific audio boundary; no training or repository redistribution |
| [GRN Portrait of Jesus (Modern)](https://globalrecordings.net/en/program/30090) | Unnamed voice, 8 MP3s, 1:15:50.217 | [English outline](https://globalrecordings.net/en/script/en/414) lists passages/music but omits the spoken passage text; not a transcript or translation | © Talking Bibles International; unmodified personal/local-ministry copying only; third-party script is used by permission |
| [LibriVox CUV Acts 1–2](https://librivox.org/acts-by-chinese-union-version/) | yuli, gender unverified, mono, 10:30.178 | Catalog-linked 1919 CUV source; intended verbatim reading, but not manually checked or time-aligned | [Public Domain Mark 1.0](https://archive.org/details/bible_cuv_acts_1112_librivox); verified for US scope, check local law elsewhere |

The gender field distinguishes publisher evidence from inference in the private manifest. Locale labels are regional coverage hints, not claims that a speaker has a particular accent; actual accent and speaking-rate labels require listening validation.

## 2026-08-22 Extension Integrity

All four GRN archives passed `unzip -t`. Durations below are sums of `afinfo` measurements over the original MP3 archive entries; the LibriVox value is measured directly from its original MP3. No media was transcoded, normalized, or committed.

| Item | Audio metadata | SHA-256 |
|---|---|---|
| GRN 64259 | ZIP, 46,654,156 bytes; 40 × stereo 44.1 kHz MP3; 2,909.309389 s | `6bc3f7f3ef7f7d9608cd18b9f4c5d5d42b1bd2b1b5b683f11a9004fbb4c6f0a8` |
| GRN 62908 | ZIP, 43,888,088 bytes; 40 × stereo 44.1 kHz MP3; 2,223.438366 s | `979f306a6195e576da669d1aa1d3fbc8ea1d1d4845e3596d2e0b2aaac9fce32f` |
| GRN 80921 | ZIP, 32,061,027 bytes; 24 × stereo 44.1 kHz MP3; 1,862.713469 s | `83f89bcfc933d6e5170fa2a2524bfb61c2bbc15a6e8f039420c8da962d10023d` |
| GRN 30090 | ZIP, 63,719,289 bytes; 8 × stereo 44.1 kHz MP3; 4,550.217143 s | `dd8a269ec82232e9696da4d531b18e96e3fc1eaf9e705b0d55c78e5c0741b034` |
| LibriVox Acts 1–2 | MP3, 10,084,654 bytes; mono 44.1 kHz; 630.177937 s | `ada35ee8263f898c3fff36b477d084d4f5ef517e304f87f32b7fcfa9346b1383` |

The private manifest also records hashes for every downloaded script, program-page snapshot, provider-policy snapshot, and LibriVox/Internet Archive metadata snapshot. Media and snapshots remain beneath the already ignored `.artifacts/sermon-corpus/` tree.

## 2026-08-23 Genuine-Sermon Extension Integrity

The four new files were acquired only from the churches' own sermon pages or media directories. Each source was probed as MP3, its byte length and SHA-256 were checked before conversion, and the source was hashed again after conversion. No item grants this project permission to train on or redistribute the recording.

| Item | Audio metadata | SHA-256 |
|---|---|---|
| VCAC — 喜乐的人生 | MP3, 36,352,964 bytes; stereo 44.1 kHz; 2,271.216327 s | `58141dabafe738cb203e99dfe97c4182e83aa1e109b83a71f476387fceedddd9` |
| VCAC — 望门兴叹 | MP3, 38,279,994 bytes; stereo 44.1 kHz; 2,391.745250 s | `02a4c09922ffbd4e095161b3f6a49b59a9da12355b30d21f4f52f823f195c7c2` |
| AACCC — 真实的敬拜 | MP3, 15,244,452 bytes; mono 32 kHz; 3,226.680000 s | `8b64d607f649929913c33725ff1c99499af9b80c63a985ce27c56e1a56b1828f` |
| ECBC — 恩召 | MP3, 28,190,573 bytes; mono 44.1 kHz; 3,067.715918 s | `a3ab7a8f2f1284104f4e0cb6c743def525a1a9d01fa19aa394cb3db5f68595b5` |

The expanded replay contains 18 logical items and 132 independent WAV tracks. FFmpeg 9.0.1 produced mono 16 kHz signed 16-bit PCM with metadata removed and bit-exact flags; a repeated conversion smoke was byte-identical. The replay manifest records 834,285,196 exact frames (52,142.824750 seconds), including 600,391,798 frames (37,524.487375 seconds) across the 12 genuine sermons. Tracks remain separate and reset state at every boundary.

This satisfies only the structural 12-sermon, eight-hour, and six-speaker floor. It does not satisfy human endpoint labels, blinded ASR accuracy, translation fidelity, soak, latency, device, or clean-Mac release gates. The replay manifest therefore deliberately keeps `release_sermon_count_gate_met=false` until those independent qualifications finish.

## Script Fidelity and Content Coverage

- GRN scripts 394, 395, and 418 explicitly describe themselves as basic translation/recording guidelines that may be explained, replaced, or omitted for a language and culture. The Chinese and English pages are useful semantic references, but they are neither subtitles nor trustworthy sentence-level gold translations.
- GRN script 414 is weaker: it is an English scripture-reference and music outline, not the full text spoken in the audio. It must not be used for word-error-rate or translation scoring.
- The LibriVox section is cataloged as chapters 1–2 read from the 1919 Chinese Union Version. That makes it an intended-verbatim reference, but no manual audio/text collation was performed and no timestamps are available. The linked text host currently presents an expired TLS certificate, so only the catalog/API provenance was snapshotted.
- The five additions deliberately vary register and theology: a publisher-labeled female program variant; a university-targeted version whose script metadata separately says “for Muslims”; Old Testament storytelling about Adam, Noah, Job, and Abraham; long-form life-of-Jesus narration with music and older audio; and a single-reader Acts/Pentecost passage. Terms include creation, sin, sacrifice/atonement, resurrection, salvation, the Holy Spirit, worship, church/family, eschatology, and apostleship.

## Best Qualification Order

1. Argyle 2025 for ASR, punctuation, and human Mandarin-to-English comparison; Argyle 2023 for female antecedent chains and cross-sentence pronoun recovery.
2. Friendship Nancy and Caleb for alternating interpretation, code switching, speaker variation, and long-session endpointing.
3. ECBC and Living Spring for independent female voices, low-bitrate stress, and endpoint-only evaluation.
4. WLACBC and REM for male voices, joint-service conditions, theological terms, and one-hour recovery tests.
5. VCAC, AACCC, and the second ECBC sermon for four independent male speakers, long-form church PA acoustics, low-bitrate stress, theology, and endpoint replay.
6. GRN 29260 for short semantic turns, salvation vocabulary, archival audio, and music rejection. Its English scripts are semantic source guides rather than translation goldens.
7. GRN 64259 and 62908 for 80 short, uniformly structured lessons, a publisher-identified female variant, and differences between general and targeted register.
8. GRN 80921 for compact narrative discourse; GRN 30090 for long turns, music boundaries, scripture-heavy language, and the official low-quality warning.
9. LibriVox Acts 1–2 for cleanly scoped public-domain scripture recitation and Pentecost/Holy Spirit terminology. Treat the text as intended-verbatim but unverified, not as a scored golden until manually collated.

## URL-Only Stress Set

YouTube content is retained only as official page or watch URLs; it is not downloaded and timed text is not extracted.

- [Hesed Church — 香香](https://www.youtube.com/watch?v=2UyFt1oqqww), 81:10. The publisher exposes Simplified Chinese, Traditional Chinese, English, Japanese, and Korean tracks; their human-versus-machine provenance still needs verification.
- [Hesed Church — 洪菊熙](https://www.youtube.com/watch?v=AXLTbXhAPVM), 46:37. Same multilingual-track caveat; English quality is not strong enough for a gold reference.
- [FHL — 尤素玉师母](https://www.ch.fhl.net/modules/tad_player/play.php?psn=457), 55:12. Taiwan female-voice and church-room endpoint sample.
- [士林教会 — 许珮雯牧师](https://www.sl-pc.org.tw/pulpit/8485), 73:00 full service. The linked PDF is human sermon material, not a timed transcript.
- [CPBC — 邱建良 Steven Yeow](https://cpbc.org.sg/sermons/chi-14-jun-2026), 49:50. Singapore Mandarin; no verified caption track.
- [Life Church — 刘明雄传道](https://www.youtube.com/watch?v=hKabawBMOPU), 47:31. Malaysia Mandarin and narrative coreference stress.
- [Life Church — 朱志山牧师](https://www.youtube.com/watch?v=wOxxnuiZ9po), 63:18. High-value Holy Spirit, baptism, filling, and regeneration vocabulary.
- [Hong Kong Christ Life Church — Trinity course](https://hongkongchristlifechurch.org/36course/), 90:15. The exposed Chinese timed-text track is marked ASR, so it is not a human caption reference.
- [Sydney Chinese SDA full service](https://sydneychinese.adventist.org.au/channels/1163/videos/34930), 112:01. Multiple participants, interpreter, music, and long-run recovery; English captions are auto-generated.

## Rights and Reproducibility

- [GRN copyright policy](https://globalrecordings.net/en/copyright) gives audio/video and scripts a default CC BY-NC-SA 4.0 license unless otherwise indicated. Every program and script still needs its own check; an item-specific notice or third-party owner controls over the default.
- Audio programs 29260, 64259, 62908, and 80921 are handled under their specific permission for unmodified personal/local-ministry copying with no sale or bundling. Program 30090 states the same practical boundary but is © Talking Bibles International. The local manifest therefore sets training and repository redistribution to false for all five GRN audio programs.
- GRN scripts 394, 395, and 418 are handled under the provider's written-material CC BY-NC-SA 4.0 default, with attribution, noncommercial, and share-alike requirements. Script 414 names third-party material used by permission, so this project does not assume the default license for it.
- The [Internet Archive Acts item](https://archive.org/details/bible_cuv_acts_1112_librivox) carries Public Domain Mark 1.0 and identifies the file as an original LibriVox recording of a public-domain text. [LibriVox's policy](https://librivox.org/pages/public-domain/) says its recordings are public domain in the United States and warns users elsewhere to check local law. The manifest permits reuse/training only with that US-scope caveat.
- [YouTube Terms](https://www.youtube.com/t/terms) control all YouTube-only candidates. The project does not bypass the player, download video/audio, or extract captions.
- Harper Church declares `ai-train=no,use=reference` in robots metadata. Its Mandarin/English pair remains a URL-only qualitative reference and is excluded from downloads and training.
- Other downloaded items are official direct files without an open reuse license. They remain private, non-commercial, gitignored QA inputs and are not training data.
- The four 2026-08-23 additions follow the same conservative boundary: first-party audio is retained only in the gitignored private QA tree, with source attribution and a delete-on-request requirement.

Re-run qualification from the manifest, verify every SHA-256 before use, and never copy an artifact into `Sources`, `Tests`, release bundles, or the public repository. This extension used no YouTube downloader and ran no ASR, translation, endpoint, or other model.

## Known Gaps

- Argyle 2025 is the only near-gold real sermon with a human bilingual full manuscript.
- No source was found with all four properties at once: spontaneous Mandarin sermon, human Chinese verbatim transcript, human English translation, and explicit open redistribution/training permission.
- GRN provides unusually useful official Chinese/English production scripts, but its own adaptation policy prevents treating them as verbatim transcripts or translations of the exact recording.
- The LibriVox sample is the only newly downloaded item with a clearly public-domain audio status; its jurisdictional warning and unverified text/audio fidelity remain explicit.
- Spoken interpreter tracks need manual speaker/time segmentation before automated sentence-level scoring.
- Speaker gender, accent, speed, room acoustics, and caption provenance must remain uncertain unless independently verified.

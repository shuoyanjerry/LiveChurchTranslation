import ASRAPI
import Foundation
import NaturalLanguage
import TranscriptAPI
import TranslationAPI

struct RecognizedSentenceSlice: Sendable {
    let utterance: RecognizedUtterance
    let audit: TranscriptSourceAudit
    let pronounGuidance: [TranslationPronounGuidance]
    let isFinalInSourceSegment: Bool
    let sourceDiscourseText: String
}

enum RecognizedSentenceSplitter {
    static func split(
        _ resolved: ResolvedDiscourseUtterance,
        languageCode: String
    ) -> [RecognizedSentenceSlice] {
        let ranges = sentenceRanges(in: resolved.utterance.text, languageCode: languageCode)
        let rawSentences = sentenceTexts(
            in: resolved.audit.rawText,
            languageCode: languageCode
        )
        return ranges.enumerated().map { ordinal, range in
            makeSlice(
                resolved,
                range: range,
                rawSentences: rawSentences,
                ordinal: ordinal,
                count: ranges.count
            )
        }
    }

    static func sentenceRanges(
        in text: String,
        languageCode: String
    ) -> [Range<String.Index>] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        tokenizer.setLanguage(NLLanguage(rawValue: languageCode))
        let fullRange = text.startIndex..<text.endIndex
        let ranges = tokenizer.tokens(for: fullRange).filter {
            !text[$0].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return ranges.isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? [fullRange]
            : ranges
    }

    private static func sentenceTexts(
        in text: String,
        languageCode: String
    ) -> [String] {
        sentenceRanges(in: text, languageCode: languageCode).map {
            text[$0].trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func makeSlice(
        _ resolved: ResolvedDiscourseUtterance,
        range: Range<String.Index>,
        rawSentences: [String],
        ordinal: Int,
        count: Int
    ) -> RecognizedSentenceSlice {
        let source = resolved.utterance.text
        let text = source[range].trimmingCharacters(in: .whitespacesAndNewlines)
        let offsets = utf16Offsets(of: range, in: source)
        let timing = sentenceTiming(
            resolved.utterance,
            lowerOffset: offsets.lower,
            upperOffset: offsets.upper,
            total: source.utf16.count,
            isFinal: ordinal == count - 1
        )
        let rawText = rawSentences.count == count ? rawSentences[ordinal] : text
        let identity = SentenceEntryIdentity.make(
            sourceSegmentID: resolved.utterance.sourceSegmentID,
            ordinal: ordinal
        )
        return RecognizedSentenceSlice(
            utterance: RecognizedUtterance(
                sourceSegmentID: identity,
                rawText: rawText,
                text: text,
                confidence: resolved.utterance.confidence,
                startedAt: timing.start,
                endedAt: timing.end
            ),
            audit: sliceAudit(resolved.audit, text: text, offsets: offsets, rawText: rawText),
            pronounGuidance: sliceGuidance(resolved.pronounGuidance, offsets: offsets),
            isFinalInSourceSegment: ordinal == count - 1,
            sourceDiscourseText: resolved.utterance.text
        )
    }

    private static func sentenceTiming(
        _ utterance: RecognizedUtterance,
        lowerOffset: Int,
        upperOffset: Int,
        total: Int,
        isFinal: Bool
    ) -> (start: Duration, end: Duration) {
        guard total > 0 else { return (utterance.startedAt, utterance.endedAt) }
        let duration = utterance.endedAt - utterance.startedAt
        let start = utterance.startedAt + duration * (Double(lowerOffset) / Double(total))
        let end =
            isFinal
            ? utterance.endedAt
            : utterance.startedAt + duration * (Double(upperOffset) / Double(total))
        return (start, max(start, end))
    }

    static func utf16Offsets(
        of range: Range<String.Index>,
        in text: String
    ) -> (lower: Int, upper: Int) {
        (
            text.utf16.distance(from: text.utf16.startIndex, to: range.lowerBound),
            text.utf16.distance(from: text.utf16.startIndex, to: range.upperBound)
        )
    }
}

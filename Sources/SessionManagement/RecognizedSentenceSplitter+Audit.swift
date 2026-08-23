import Foundation
import TranscriptAPI
import TranslationAPI

extension RecognizedSentenceSplitter {
    static func sliceAudit(
        _ audit: TranscriptSourceAudit,
        text: String,
        offsets: (lower: Int, upper: Int),
        rawText: String
    ) -> TranscriptSourceAudit {
        TranscriptSourceAudit(
            rawText: rawText,
            corrections: audit.corrections.compactMap {
                sliceCorrection($0, text: text, offsets: offsets)
            },
            pronounDecisions: audit.pronounDecisions.compactMap {
                sliceDecision($0, offsets: offsets)
            }
        )
    }

    static func sliceGuidance(
        _ values: [TranslationPronounGuidance],
        offsets: (lower: Int, upper: Int)
    ) -> [TranslationPronounGuidance] {
        values.compactMap { value in
            guard
                contains(
                    location: value.sourceRange.location,
                    length: value.sourceRange.length,
                    offsets: offsets
                )
            else { return nil }
            return TranslationPronounGuidance(
                sourceRange: TranslationSourceRange(
                    location: value.sourceRange.location - offsets.lower,
                    length: value.sourceRange.length
                ),
                resolution: value.resolution
            )
        }
    }

    private static func sliceCorrection(
        _ value: TranscriptSourceCorrection,
        text: String,
        offsets: (lower: Int, upper: Int)
    ) -> TranscriptSourceCorrection? {
        guard let location = value.utf16Location, let length = value.utf16Length else {
            return text.localizedStandardContains(value.replacementText)
                || text.localizedStandardContains(value.observedText) ? value : nil
        }
        guard contains(location: location, length: length, offsets: offsets) else { return nil }
        return TranscriptSourceCorrection(
            observedText: value.observedText,
            replacementText: value.replacementText,
            kind: value.kind,
            reason: value.reason,
            confidence: value.confidence,
            evidenceSequence: value.evidenceSequence,
            evidenceText: value.evidenceText,
            utf16Location: location - offsets.lower,
            utf16Length: length
        )
    }

    private static func sliceDecision(
        _ value: TranscriptSourcePronounDecision,
        offsets: (lower: Int, upper: Int)
    ) -> TranscriptSourcePronounDecision? {
        guard
            contains(
                location: value.utf16Location,
                length: value.utf16Length,
                offsets: offsets
            )
        else { return nil }
        return TranscriptSourcePronounDecision(
            resolution: value.resolution,
            utf16Location: value.utf16Location - offsets.lower,
            utf16Length: value.utf16Length,
            reason: value.reason,
            confidence: value.confidence,
            evidenceSequence: value.evidenceSequence,
            evidenceText: value.evidenceText
        )
    }

    private static func contains(
        location: Int,
        length: Int,
        offsets: (lower: Int, upper: Int)
    ) -> Bool {
        location >= offsets.lower && location + length <= offsets.upper
    }
}

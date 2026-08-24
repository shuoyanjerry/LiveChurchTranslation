import Foundation
import TranslationAPI

extension HyMT2PronounPlan {
    static let maximumOccurrenceCount = 9_999

    static func markerNamespace(_ requestID: UUID) -> String {
        String(
            requestID.uuidString
                .replacingOccurrences(of: "-", with: "")
                .uppercased()
                .prefix(12)
        )
    }

    static func insertProtectedBlocks(
        in source: String,
        occurrences: [HyMT2PronounOccurrence]
    ) throws -> String {
        var result = ""
        var cursor = source.startIndex
        for occurrence in occurrences {
            let sourceRange = occurrence.sourceRange
            guard
                let range = Range(
                    NSRange(location: sourceRange.location, length: sourceRange.length),
                    in: source
                )
            else {
                throw OutputValidationFailure(
                    issues: [
                        .pronounSourceRangeNotOnCharacterBoundary(
                            sourceRange.location,
                            sourceRange.length
                        )
                    ]
                )
            }
            result += source[cursor..<range.lowerBound]
            result += occurrence.modelVisibleGlyph
            let consumedUpperBound = consumePossessiveParticle(
                after: range.upperBound,
                for: occurrence,
                in: source,
                result: &result
            )
            result += occurrence.protectedBlock
            if needsWordSeparator(after: consumedUpperBound, in: source) {
                result += " "
            }
            cursor = consumedUpperBound
        }
        result += source[cursor...]
        return result
    }

    private static func consumePossessiveParticle(
        after index: String.Index,
        for occurrence: HyMT2PronounOccurrence,
        in source: String,
        result: inout String
    ) -> String.Index {
        guard occurrence.morphologyHint.isPossessive,
            index < source.endIndex,
            source[index] == "的"
        else { return index }
        let upperBound = source.index(after: index)
        result += source[index..<upperBound]
        return upperBound
    }

    static func morphologyHint(
        after sourceRange: TranslationSourceRange,
        in source: String
    ) -> HyMT2PronounMorphologyHint {
        guard
            let range = Range(
                NSRange(location: sourceRange.location, length: sourceRange.length),
                in: source
            ),
            range.upperBound < source.endIndex,
            source[range.upperBound] == "的"
        else { return .unspecified }
        var afterParticle = source.index(after: range.upperBound)
        if afterParticle < source.endIndex, source[afterParticle] == "确" {
            return .unspecified
        }
        while afterParticle < source.endIndex, source[afterParticle].isWhitespace {
            afterParticle = source.index(after: afterParticle)
        }
        guard afterParticle < source.endIndex,
            !source[afterParticle].isPunctuation
        else { return .possessiveIndependent }
        return .possessiveDeterminer
    }

    private static func needsWordSeparator(
        after index: String.Index,
        in source: String
    ) -> Bool {
        guard index < source.endIndex else { return false }
        let next = source[index]
        return next.isLetter || next.isNumber
    }
}

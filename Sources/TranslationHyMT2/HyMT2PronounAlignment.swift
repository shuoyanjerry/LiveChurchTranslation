import Foundation
import TranslationAPI

struct HyMT2PronounOccurrence: Equatable, Sendable {
    let identifier: String
    let markerName: String
    let sourceRange: TranslationSourceRange
    let resolution: TranslationPronounResolution
    let sourceGlyph: String

    var protectedBlock: String {
        let token = HyMT2PronounResolutionToken.value(for: resolution)
        return "<QLR_\(markerName)>\(token)</QLR_\(markerName)>"
    }

    var modelVisibleGlyph: String {
        switch resolution {
        case .unresolvedSpokenMandarin: "they"
        case .verifiedFemale: "she"
        case .verifiedMale: "他"
        case .verifiedDeity: "祂"
        }
    }
}

struct HyMT2PronounPlan: Equatable, Sendable {
    let protectedSource: String
    let occurrences: [HyMT2PronounOccurrence]

    static func make(
        source: String,
        guidance: [TranslationPronounGuidance],
        requestID: UUID
    ) throws -> HyMT2PronounPlan? {
        guard !guidance.isEmpty else { return nil }
        guard guidance.count <= maximumOccurrenceCount else {
            throw OutputValidationFailure(
                issues: [.tooManyPronounOccurrences(guidance.count)]
            )
        }
        let validated = try HyMT2PronounRangeValidator.validate(
            source: source,
            guidance: guidance
        )
        let namespace = markerNamespace(requestID)
        let occurrences = validated.enumerated().map { index, item in
            let identifier = String(format: "P%04d", index + 1)
            return HyMT2PronounOccurrence(
                identifier: identifier,
                markerName: "\(namespace)_\(identifier)",
                sourceRange: item.guidance.sourceRange,
                resolution: item.guidance.resolution,
                sourceGlyph: item.glyph
            )
        }
        return HyMT2PronounPlan(
            protectedSource: try insertProtectedBlocks(in: source, occurrences: occurrences),
            occurrences: occurrences
        )
    }

    private static let maximumOccurrenceCount = 9_999

    private static func markerNamespace(_ requestID: UUID) -> String {
        String(
            requestID.uuidString
                .replacingOccurrences(of: "-", with: "")
                .uppercased()
                .prefix(12)
        )
    }

    private static func insertProtectedBlocks(
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
            result += occurrence.protectedBlock
            if needsWordSeparator(after: range.upperBound, in: source) {
                result += " "
            }
            cursor = range.upperBound
        }
        result += source[cursor...]
        return result
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

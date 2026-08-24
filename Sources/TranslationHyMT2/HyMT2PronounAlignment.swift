import Foundation
import TranslationAPI

struct HyMT2PronounOccurrence: Equatable, Sendable {
    let identifier: String
    let markerName: String
    let sourceRange: TranslationSourceRange
    let resolution: TranslationPronounResolution
    let sourceGlyph: String
    let morphologyHint: HyMT2PronounMorphologyHint

    var protectedBlock: String {
        let compactName = markerName.replacingOccurrences(of: "_", with: "")
        let resolutionCode = HyMT2PronounResolutionToken.compactCode(for: resolution)
        return "<Q\(compactName)\(resolutionCode)>"
    }

    var modelVisibleGlyph: String { sourceGlyph }
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
                sourceGlyph: item.glyph,
                morphologyHint: morphologyHint(
                    after: item.guidance.sourceRange,
                    in: source
                )
            )
        }
        return HyMT2PronounPlan(
            protectedSource: try insertProtectedBlocks(in: source, occurrences: occurrences),
            occurrences: occurrences
        )
    }

}

enum HyMT2PronounMorphologyHint: Equatable, Sendable {
    case unspecified
    case possessiveDeterminer
    case possessiveIndependent

    var isPossessive: Bool {
        self != .unspecified
    }
}

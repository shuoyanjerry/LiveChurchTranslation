import Foundation
@testable import TranslationHyMT2

extension HyMT2SchemaShadowPlanBuilder {
    static func annotatedPronouns(
        _ source: String,
        occurrences: [HyMT2PronounOccurrence]
    ) throws -> String {
        var result = ""
        var cursor = source.startIndex
        for occurrence in occurrences {
            let range = NSRange(
                location: occurrence.sourceRange.location,
                length: occurrence.sourceRange.length
            )
            guard let sourceRange = Range(range, in: source) else {
                throw HyMT2SchemaShadowFailureCode.schemaInvalid
            }
            result += source[cursor..<sourceRange.upperBound]
            result += "[\(occurrence.identifier)]"
            cursor = sourceRange.upperBound
        }
        result += source[cursor...]
        return result
    }

    static func pronounOccurrences(
        _ occurrences: [HyMT2PronounOccurrence],
        anchors: [[String]]
    ) -> [HyMT2SchemaShadowOccurrence] {
        zip(occurrences, anchors).map { item, anchorGroup in
            let surfaces = pronounSurfaces(item.resolution)
            return HyMT2SchemaShadowOccurrence(
                identifier: item.identifier,
                allowedSurfaces: surfaces,
                expectedSurfaces: Set(surfaces),
                anchorAlternatives: anchorGroup,
                resolution: item.resolution
            )
        }
    }

    static func requestID(_ index: Int) -> UUID {
        let suffix = String(format: "%012X", index + 1)
        guard let value = UUID(uuidString: "C0DEC0DE-2026-4A22-D000-\(suffix)") else {
            preconditionFailure("Static public schema-shadow UUID is malformed.")
        }
        return value
    }
}

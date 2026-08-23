import Foundation
import TranslationAPI
import TranslationQualificationSupport

enum HyMTNegationDiagnosticRequestFactory {
    static func make(
        segment: TranslationQualificationSegment,
        classifiedAttempt: TranslationQualificationAttempt,
        recent: [HyMTQualificationPersistedTurn]
    ) throws -> TranslationRequest {
        guard
            classifiedAttempt.segmentID == segment.id,
            classifiedAttempt.contextSegmentIDs == recent.segmentIDs
        else {
            throw TranslationQualificationError.invalidReport(
                "classified diagnostic replay context is inconsistent"
            )
        }
        let source = classifiedAttempt.translationSourceText
        return TranslationRequest(
            id: requestID(segment),
            sourceText: source,
            glossary: HyMTQualificationGlossary.matchedTerms(in: source),
            context: recent.translationEntries,
            pronounGuidance: try pronounGuidance(
                segment: segment,
                attempt: classifiedAttempt,
                source: source
            )
        )
    }

    private static func pronounGuidance(
        segment: TranslationQualificationSegment,
        attempt: TranslationQualificationAttempt,
        source: String
    ) throws -> [TranslationPronounGuidance] {
        guard segment.pronounOccurrences.count == attempt.pronounResults.count else {
            throw TranslationQualificationError.invalidReport(
                "classified pronoun evidence count is inconsistent"
            )
        }
        return try zip(segment.pronounOccurrences, attempt.pronounResults).compactMap { occurrence, result in
            guard occurrence.id == result.occurrenceID else {
                throw TranslationQualificationError.invalidReport(
                    "classified pronoun evidence order is inconsistent"
                )
            }
            guard occurrence.tokenClass == .singularPronoun else { return nil }
            guard let resolution = resolution(result.actualGuidance) else { return nil }
            return TranslationPronounGuidance(
                sourceRange: try sourceRange(occurrence.unicodeScalarOffset, source: source),
                resolution: resolution
            )
        }
    }

    private static func sourceRange(
        _ scalarOffset: Int,
        source: String
    ) throws -> TranslationSourceRange {
        let scalars = source.unicodeScalars
        guard scalarOffset >= 0, scalarOffset < scalars.count else {
            throw TranslationQualificationError.invalidReport(
                "classified pronoun range is outside replay source"
            )
        }
        let index = scalars.index(scalars.startIndex, offsetBy: scalarOffset)
        let next = scalars.index(after: index)
        let prefix = String(scalars[..<index]).utf16.count
        let length = String(scalars[index..<next]).utf16.count
        return TranslationSourceRange(location: prefix, length: length)
    }

    private static func resolution(_ value: String) -> TranslationPronounResolution? {
        switch value {
        case "unresolvedSpokenMandarin": .unresolvedSpokenMandarin
        case "verifiedFemale": .verifiedFemale
        case "verifiedMale": .verifiedMale
        case "verifiedDeity": .verifiedDeity
        case "none": nil
        default: nil
        }
    }

    private static func requestID(_ segment: TranslationQualificationSegment) -> UUID {
        let seed = "hymt-negation-diagnostic:\(segment.sourceID):\(segment.sequence):\(segment.id)"
        let hash = TranslationQualificationSHA256.hash(data: Data(seed.utf8))
        let value = [
            hash.prefix(8), hash.dropFirst(8).prefix(4), hash.dropFirst(12).prefix(4),
            hash.dropFirst(16).prefix(4), hash.dropFirst(20).prefix(12),
        ].map(String.init).joined(separator: "-")
        guard let identifier = UUID(uuidString: value) else {
            preconditionFailure("SHA-256 request identifier is malformed.")
        }
        return identifier
    }
}

import DiscourseResolutionAPI
import TranslationQualificationSupport

struct DiscourseQualificationGuidanceEvaluation {
    let occurrences: [DiscourseQualificationOccurrenceReport]
    let unmappedGuidanceCount: Int
    let duplicateGuidanceLocationCount: Int
}

enum DiscourseQualificationGuidanceEvaluator {
    static func evaluate(
        segment: TranslationQualificationSegment,
        guidance: [DiscoursePronounGuidance]
    ) throws -> DiscourseQualificationGuidanceEvaluation {
        let locations = try occurrenceLocations(segment)
        let guidanceByLocation = Dictionary(grouping: guidance, by: \.range.location)
        let observations = segment.pronounOccurrences.map { occurrence in
            TranslationGuidanceObservation(
                occurrenceID: occurrence.id,
                resolution: mappedResolution(
                    guidanceByLocation[locations[occurrence.id] ?? -1, default: []],
                    expectedLength: occurrence.observedGlyph.utf16.count
                )
            )
        }
        let results = TranslationPronounEvaluator.evaluate(
            occurrences: segment.pronounOccurrences,
            guidance: observations,
            realizations: [],
            hypothesisAvailable: false
        )
        return DiscourseQualificationGuidanceEvaluation(
            occurrences: results.map(report),
            unmappedGuidanceCount: unmappedCount(guidance, locations: locations),
            duplicateGuidanceLocationCount: guidanceByLocation.values.filter { $0.count > 1 }.count
        )
    }

    private static func report(
        _ result: TranslationQualificationPronounResult
    ) -> DiscourseQualificationOccurrenceReport {
        DiscourseQualificationOccurrenceReport(
            occurrenceID: result.occurrenceID,
            expectedGuidanceClass: result.expectedGuidance.rawValue,
            actualGuidanceClass: result.actualGuidance,
            outcomeClass: DiscourseQualificationOutcomeClassifier.classify(
                expected: result.expectedGuidance,
                actual: result.actualGuidance
            ),
            policyStatusClass: DiscourseQualificationOutcomeClassifier.isPolicyMatch(
                result.guidanceStatus
            )
        )
    }

    private static func mappedResolution(
        _ values: [DiscoursePronounGuidance],
        expectedLength: Int
    ) -> String? {
        guard values.count <= 1 else { return "duplicateGuidance" }
        guard let value = values.first else { return nil }
        guard value.range.length == expectedLength else { return "invalidGuidanceRange" }
        switch value.resolution {
        case .unresolved: return "unresolvedSpokenMandarin"
        case .verified(let gender, _, _, _):
            return gender == .female ? "verifiedFemale" : "verifiedMale"
        case .verifiedDeity: return "verifiedDeity"
        }
    }

    private static func occurrenceLocations(
        _ segment: TranslationQualificationSegment
    ) throws -> [String: Int] {
        var locations: [String: Int] = [:]
        for occurrence in segment.pronounOccurrences {
            locations[occurrence.id] = try utf16Location(
                scalarOffset: occurrence.unicodeScalarOffset,
                in: segment.observedASRAmbiguousChinese
            )
        }
        return locations
    }

    private static func utf16Location(scalarOffset: Int, in text: String) throws -> Int {
        let scalars = text.unicodeScalars
        guard
            scalarOffset >= 0,
            let index = scalars.index(
                scalars.startIndex,
                offsetBy: scalarOffset,
                limitedBy: scalars.endIndex
            ),
            index < scalars.endIndex
        else {
            throw TranslationQualificationError.invalidManifest(
                "pronoun occurrence offset is outside observed text"
            )
        }
        return String(scalars[..<index]).utf16.count
    }

    private static func unmappedCount(
        _ guidance: [DiscoursePronounGuidance],
        locations: [String: Int]
    ) -> Int {
        let expected = Set(locations.values)
        return guidance.filter { !expected.contains($0.range.location) }.count
    }
}

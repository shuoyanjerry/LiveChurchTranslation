import Foundation
import TranslationAPI
@testable import TranslationHyMT2

enum HyMT2SchemaShadowPlanBuilder {
    static func negation(
        _ fixture: HyMT2NegationShadowQ4Fixture,
        index: Int
    ) throws -> HyMT2SchemaShadowPlan {
        let current = try fixture.plan(encoding: .originalCue, index: index)
        guard current.occurrences.count == fixture.occurrenceAnchorAlternatives.count else {
            throw HyMT2SchemaShadowFailureCode.schemaInvalid
        }
        let pairs = zip(current.occurrences, fixture.occurrenceAnchorAlternatives)
        let occurrences = pairs.map { item, anchors in
            HyMT2SchemaShadowOccurrence(
                identifier: item.identifier,
                allowedSurfaces: negationSurfaces,
                expectedSurfaces: Set(negationSurfaces),
                anchorAlternatives: anchors,
                resolution: nil
            )
        }
        let annotated = current.occurrences.reduce(current.protectedSource) { value, item in
            value.replacingOccurrences(of: item.protectedBlock, with: "[\(item.identifier)]")
        }
        return HyMT2SchemaShadowPlan(
            fixtureID: fixture.identifier,
            family: .negation,
            source: current.source,
            prompt: HyMT2SchemaShadowPrompt.make(
                annotatedSource: annotated,
                family: .negation,
                occurrences: occurrences
            ),
            occurrences: occurrences,
            globalAnchorGroups: fixture.globalAnchorGroups
        )
    }

    static func pronoun(
        _ fixture: HyMT2SchemaShadowPronounFixture,
        index: Int
    ) throws -> HyMT2SchemaShadowPlan {
        let request = try fixture.base.request(id: requestID(index))
        guard
            let current = try HyMT2PronounPlan.make(
                source: request.sourceText,
                guidance: request.pronounGuidance,
                requestID: request.id
            )
        else {
            throw HyMT2SchemaShadowFailureCode.schemaInvalid
        }
        guard current.occurrences.count == fixture.occurrenceAnchorAlternatives.count else {
            throw HyMT2SchemaShadowFailureCode.schemaInvalid
        }
        let occurrences = pronounOccurrences(
            current.occurrences,
            anchors: fixture.occurrenceAnchorAlternatives
        )
        let annotated = try annotatedPronouns(request.sourceText, occurrences: current.occurrences)
        return HyMT2SchemaShadowPlan(
            fixtureID: fixture.base.name,
            family: .pronoun,
            source: request.sourceText,
            prompt: HyMT2SchemaShadowPrompt.make(
                annotatedSource: annotated,
                family: .pronoun,
                occurrences: occurrences
            ),
            occurrences: occurrences,
            globalAnchorGroups: fixture.globalAnchorGroups
        )
    }

    static func pronounSurfaces(
        _ resolution: TranslationPronounResolution
    ) -> [String] {
        switch resolution {
        case .unresolvedSpokenMandarin:
            ["they", "them", "their", "theirs", "themself", "themselves"]
        case .verifiedFemale:
            ["she", "her", "hers", "herself"]
        case .verifiedMale, .verifiedDeity:
            ["he", "him", "his", "himself"]
        }
    }

    static let negationSurfaces = [
        "not", "no", "never", "cannot", "can't", "won't", "isn't", "aren't",
        "wasn't", "weren't", "don't", "doesn't", "didn't", "hasn't", "haven't",
        "hadn't", "shouldn't", "wouldn't", "couldn't", "mustn't", "without",
        "needn't", "shan't", "neither", "nor",
    ]

}

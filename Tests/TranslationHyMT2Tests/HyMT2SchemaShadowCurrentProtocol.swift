import TranslationAPI
@testable import TranslationHyMT2

struct HyMT2SchemaShadowSemanticInput {
    let target: String
    let carrier: String
    let tokens: [String: String]
    let bindings: [String: HyMT2SchemaShadowBinding]
}

enum HyMT2SchemaShadowCurrentProtocol {
    static func negationPlan(
        _ fixture: HyMT2NegationShadowQ4Fixture,
        index: Int
    ) throws -> HyMT2NegationShadowPlan {
        try fixture.plan(encoding: .originalCue, index: index)
    }

    static func negationPrompt(_ plan: HyMT2NegationShadowPlan) -> String {
        HyMT2NegationMarkerShadowPrompt.make(plan)
    }

    static func parseNegation(
        _ output: String,
        current: HyMT2NegationShadowPlan
    ) throws -> HyMT2SchemaShadowSemanticInput {
        let parsed = try HyMT2NegationMarkerShadowParser.parse(output, plan: current)
        let bindings = Dictionary(
            uniqueKeysWithValues: parsed.bindings.map {
                ($0.identifier, HyMT2SchemaShadowBinding(surface: $0.englishNegator))
            }
        )
        let tokens = Dictionary(
            uniqueKeysWithValues: current.occurrences.map {
                ($0.identifier, $0.protectedBlock)
            }
        )
        return HyMT2SchemaShadowSemanticInput(
            target: parsed.cleanTarget,
            carrier: output,
            tokens: tokens,
            bindings: bindings
        )
    }

    static func pronounPlan(
        _ fixture: HyMT2SchemaShadowPronounFixture,
        index: Int
    ) throws -> HyMT2PronounPlan {
        let request = try fixture.base.request(
            id: HyMT2SchemaShadowPlanBuilder.requestID(index)
        )
        guard
            let plan = try HyMT2PronounPlan.make(
                source: request.sourceText,
                guidance: request.pronounGuidance,
                requestID: request.id
            )
        else {
            throw HyMT2SchemaShadowFailureCode.currentProtocol
        }
        return plan
    }

    static func pronounPrompt(
        _ plan: HyMT2PronounPlan,
        source: String
    ) -> String {
        HyMT2PromptBuilder.prompt(
            source: source,
            targetLanguage: "en",
            terms: [],
            pronounPlan: plan,
            strict: true
        )
    }

    static func parsePronoun(
        _ output: String,
        current: HyMT2PronounPlan
    ) throws -> HyMT2SchemaShadowSemanticInput {
        let parsed = try HyMT2PronounMarkerParser.parse(output, plan: current)
        let bindings = Dictionary(
            uniqueKeysWithValues: parsed.realizations.map {
                (
                    $0.occurrence.identifier,
                    HyMT2SchemaShadowBinding(surface: canonicalSurface($0.realizationClass))
                )
            }
        )
        let tokens = Dictionary(
            uniqueKeysWithValues: current.occurrences.map {
                ($0.identifier, $0.protectedBlock)
            }
        )
        return HyMT2SchemaShadowSemanticInput(
            target: parsed.cleanTarget,
            carrier: output,
            tokens: tokens,
            bindings: bindings
        )
    }

    private static func canonicalSurface(_ value: HyMT2PronounRealizationClass) -> String {
        switch value {
        case .singularThey: "they"
        case .feminine: "she"
        case .masculine: "he"
        }
    }
}

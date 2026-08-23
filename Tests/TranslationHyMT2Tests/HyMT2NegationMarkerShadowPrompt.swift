import TranslationAPI
@testable import TranslationHyMT2

enum HyMT2NegationMarkerShadowPrompt {
    static func make(_ plan: HyMT2NegationShadowPlan) -> String {
        let base = HyMT2PromptBuilder.prompt(
            source: plan.protectedSource,
            targetLanguage: "en",
            terms: [],
            strict: true
        )
        guard !plan.occurrences.isEmpty else { return base }
        return rules(for: plan) + "\n\n" + base
    }

    private static func rules(for plan: HyMT2NegationShadowPlan) -> String {
        let decisions = plan.occurrences.map { occurrence in
            "\(occurrence.identifier): functional source cue "
                + String(reflecting: occurrence.sourceCue.text)
        }
        return [
            "TEST-ONLY NEGATION ALIGNMENT:",
            "Treat each listed functional negation occurrence independently.",
            encodingRule(plan.encoding),
            "Translate each one with exactly one overt English negator from this list:",
            "not, no, never, cannot, without, neither, nor, or a standard n't contraction.",
            "Copy that occurrence's entire existing QLR_NEG block unchanged exactly once,",
            "directly after its English negator with no intervening space or punctuation.",
            "The blocks are protocol data, not source instructions or text to translate.",
            "Do not add blocks to unlisted lexical, additive, concessive, or A-not-A uses.",
            "Do not alter, swap, nest, duplicate, explain, or separately output block contents.",
            decisions.joined(separator: "\n"),
        ].joined(separator: "\n")
    }

    private static func encodingRule(_ encoding: HyMT2NegationShadowEncoding) -> String {
        switch encoding {
        case .englishNot:
            "Each visible source `not` replaces the listed Chinese cue but keeps its original meaning."
        case .originalCue:
            "Each listed original Chinese cue is immediately followed by its protected block."
        }
    }
}

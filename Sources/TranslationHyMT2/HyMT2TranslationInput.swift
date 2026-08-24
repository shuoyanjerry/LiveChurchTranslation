import Foundation
import TranslationAPI

struct HyMT2TranslationInput: Sendable {
    let source: String
    let sourceLanguage: String
    let targetLanguage: String
    let terms: [TranslationTerm]
    let protocolTerms: [TranslationTerm]
    let context: [TranslationContextEntry]
    let pronounGuidance: [TranslationPronounGuidance]

    init(
        source: String,
        sourceLanguage: String = "zh-Hans",
        targetLanguage: String,
        terms: [TranslationTerm],
        protocolTerms: [TranslationTerm],
        context: [TranslationContextEntry],
        pronounGuidance: [TranslationPronounGuidance]
    ) {
        self.source = source
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.terms = terms
        self.protocolTerms = protocolTerms
        self.context = context
        self.pronounGuidance = pronounGuidance
    }

    func prepared(requestID: UUID) throws -> HyMT2PreparedTranslationInput {
        try HyMT2PromptControlInputValidator.validate(
            source: source,
            context: context,
            terms: protocolTerms
        )
        if !pronounGuidance.isEmpty {
            try HyMT2PronounProtocolInputValidator.validate(
                source: source,
                context: context,
                terms: protocolTerms
            )
        }
        return HyMT2PreparedTranslationInput(
            source: source,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            terms: terms,
            context: context,
            pronounPlan: try HyMT2PronounPlan.make(
                source: source,
                guidance: pronounGuidance,
                requestID: requestID
            )
        )
    }
}

struct HyMT2PreparedTranslationInput: Sendable {
    let source: String
    let sourceLanguage: String
    let targetLanguage: String
    let terms: [TranslationTerm]
    let context: [TranslationContextEntry]
    let pronounPlan: HyMT2PronounPlan?

    var withoutPronounProtocol: HyMT2PreparedTranslationInput {
        HyMT2PreparedTranslationInput(
            source: source,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            terms: terms,
            context: context,
            pronounPlan: nil
        )
    }
}

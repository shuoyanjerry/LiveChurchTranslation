import TranslationAPI

enum HyMT2TranslationInputFactory {
    static func make(
        _ request: TranslationRequest,
        trimmedSource: String,
        maximumGlossaryTerms: Int
    ) -> HyMT2TranslationInput {
        let source = request.pronounGuidance.isEmpty ? trimmedSource : request.sourceText
        let terms = TranslationTermMatcher.matched(
            in: source,
            from: request.glossary,
            limit: maximumGlossaryTerms
        )
        return HyMT2TranslationInput(
            source: source,
            sourceLanguage: request.sourceLanguage,
            targetLanguage: request.targetLanguage,
            terms: terms,
            protocolTerms: request.glossary,
            context: request.context,
            pronounGuidance: request.pronounGuidance
        )
    }
}

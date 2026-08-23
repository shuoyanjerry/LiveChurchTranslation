import TranslationAPI

enum HyMT2PromptControlInputValidator {
    static func validate(
        source: String,
        context: [TranslationContextEntry],
        terms: [TranslationTerm]
    ) throws {
        let values =
            [source]
            + context.flatMap { [$0.sourceText, $0.targetText] }
            + terms.flatMap {
                [$0.source, $0.target] + $0.sourceAliases + $0.acceptedTargets
            }
        guard !values.contains(where: HyMT2PromptControlDelimiter.occurs) else {
            throw HyMT2Error.invalidInput
        }
    }
}

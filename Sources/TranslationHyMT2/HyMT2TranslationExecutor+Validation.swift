import Foundation

extension HyMT2TranslationExecutor {
    func retryCapability(
        for output: String,
        input: HyMT2PreparedTranslationInput,
        failure: OutputValidationFailure
    ) -> HyMT2FlatPronounRetryCapability? {
        input.pronounPlan.flatMap { plan in
            HyMT2FlatPronounRetryAuthorizer.capability(
                for: output,
                plan: plan,
                failure: failure,
                source: input.source,
                requiredTerms: input.terms
            )
        }
    }

    func prepare(
        _ input: HyMT2TranslationInput,
        requestID: UUID
    ) throws -> HyMT2PreparedTranslationInput {
        do {
            return try input.prepared(requestID: requestID)
        } catch let failure as OutputValidationFailure {
            throw HyMT2Error.invalidOutput(failure.safeDescriptions)
        }
    }

    func validate(
        _ output: String,
        input: HyMT2PreparedTranslationInput,
        flatRetryCapability: HyMT2FlatPronounRetryCapability?,
        strictRetry: Bool
    ) throws -> HyMT2ValidatedOutput {
        try HyMT2OutputValidator.validated(
            output,
            source: input.source,
            requiredTerms: input.terms,
            sourceLanguage: input.sourceLanguage,
            targetLanguage: input.targetLanguage,
            pronounPlan: input.pronounPlan,
            flatRetryCapability: flatRetryCapability,
            strictRetry: strictRetry,
            context: input.context
        )
    }
}

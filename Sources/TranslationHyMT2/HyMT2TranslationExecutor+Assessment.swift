import Foundation

extension HyMT2TranslationExecutor {
    func acceptedTarget(
        _ output: String,
        input: HyMT2PreparedTranslationInput,
        requestID: UUID,
        phase: HyMT2AttemptPhase,
        flatRetryCapability: HyMT2FlatPronounRetryCapability? = nil
    ) async throws -> HyMT2AssessedOutput {
        let target = try validate(
            output,
            input: input,
            flatRetryCapability: flatRetryCapability,
            strictRetry: phase == .strictRetry
        )
        await record(requestID, phase: phase, outcome: .accepted)
        await recordPronouns(target, requestID: requestID, phase: phase)
        return .approved(target: target.target)
    }

    func prompt(
        _ input: HyMT2PreparedTranslationInput,
        strict: Bool,
        pronounCorrection: HyMT2PronounRetryCorrection? = nil
    ) -> String {
        HyMT2PromptBuilder.prompt(
            source: input.source,
            targetLanguage: input.targetLanguage,
            sourceLanguage: input.sourceLanguage,
            terms: input.terms,
            context: input.context,
            pronounPlan: input.pronounPlan,
            pronounRetryCorrection: pronounCorrection,
            strict: strict
        )
    }
}

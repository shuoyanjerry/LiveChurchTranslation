import Foundation

extension HyMT2TranslationExecutor {
    func safetyFallback(
        _ context: HyMT2TranslationExecutionContext
    ) async throws -> HyMT2AssessedOutput {
        let input = context.input.withoutPronounProtocol
        let output = try await observedCompletion(
            prompt(input, strict: true),
            endpoint: context.endpoint,
            requestID: context.requestID,
            phase: .safetyFallback
        )
        do {
            let assessed = try assessSafetyFallback(
                output,
                input: input,
                protocolPlan: context.input.pronounPlan
            )
            await record(context.requestID, phase: .safetyFallback, outcome: .accepted)
            return assessed
        } catch let failure as OutputValidationFailure {
            await recordRejection(
                failure,
                requestID: context.requestID,
                phase: .safetyFallback
            )
            throw HyMT2Error.invalidOutput(failure.safeDescriptions)
        }
    }

    private func assessSafetyFallback(
        _ output: String,
        input: HyMT2PreparedTranslationInput,
        protocolPlan: HyMT2PronounPlan?
    ) throws -> HyMT2AssessedOutput {
        guard
            !HyMT2PronounProtocolResidualValidator.containsProtocolFragment(
                in: output,
                plan: protocolPlan
            )
        else {
            throw OutputValidationFailure(issues: [.promptControlDelimiter])
        }
        let assessed = try assessedSafetyFallbackOutput(output, input: input)
        guard
            !HyMT2MetaText.isProbableSourceEcho(
                target: assessed.target,
                source: input.source,
                sourceLanguage: input.sourceLanguage,
                targetLanguage: input.targetLanguage
            )
        else {
            throw OutputValidationFailure(issues: [.metaText])
        }
        return .pronounSafetyFallback(
            target: assessed.target,
            reviewIssueCodes: assessed.review?.issueCodes ?? [],
            validationIssueCount: assessed.validationIssueCount
        )
    }

    private func assessedSafetyFallbackOutput(
        _ output: String,
        input: HyMT2PreparedTranslationInput
    ) throws -> HyMT2AssessedOutput {
        do {
            let validated = try validate(
                output,
                input: input,
                flatRetryCapability: nil,
                strictRetry: false
            )
            return .approved(target: validated.target)
        } catch let failure as OutputValidationFailure {
            guard
                let publishable = HyMT2BestEffortExtractor.assess(
                    output,
                    failure: failure,
                    input: input
                )
            else { throw failure }
            return publishable
        }
    }
}

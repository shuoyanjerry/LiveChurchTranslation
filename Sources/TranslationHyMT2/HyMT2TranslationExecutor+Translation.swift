import Foundation

extension HyMT2TranslationExecutor {
    func translate(
        _ input: HyMT2TranslationInput,
        endpoint: LlamaServerEndpoint,
        requestID: UUID
    ) async throws -> HyMT2AssessedOutput {
        let context = HyMT2TranslationExecutionContext(
            input: try prepare(input, requestID: requestID),
            endpoint: endpoint,
            requestID: requestID
        )
        let first = try await observedCompletion(
            prompt(context.input, strict: false),
            endpoint: endpoint,
            requestID: requestID,
            phase: .initial
        )
        return try await assessInitial(first, context: context)
    }

    private func assessInitial(
        _ output: String,
        context: HyMT2TranslationExecutionContext
    ) async throws -> HyMT2AssessedOutput {
        do {
            return try await acceptedTarget(
                output,
                input: context.input,
                requestID: context.requestID,
                phase: .initial
            )
        } catch let failure as OutputValidationFailure {
            await recordRejection(failure, requestID: context.requestID, phase: .initial)
            return try await strictRetry(
                retryRequest(output: output, failure: failure, context: context)
            )
        }
    }

    private func retryRequest(
        output: String,
        failure: OutputValidationFailure,
        context: HyMT2TranslationExecutionContext
    ) -> HyMT2StrictRetryRequest {
        HyMT2StrictRetryRequest(
            context: context,
            pronounCorrection: HyMT2PronounRetryCorrection(
                issues: failure.issues,
                plan: context.input.pronounPlan,
                source: context.input.source
            ),
            flatRetryCapability: retryCapability(
                for: output,
                input: context.input,
                failure: failure
            ),
            fallback: HyMT2BestEffortExtractor.assess(
                output,
                failure: failure,
                input: context.input
            )
        )
    }
}

struct HyMT2TranslationExecutionContext: Sendable {
    let input: HyMT2PreparedTranslationInput
    let endpoint: LlamaServerEndpoint
    let requestID: UUID
}

struct HyMT2StrictRetryRequest: Sendable {
    let context: HyMT2TranslationExecutionContext
    let pronounCorrection: HyMT2PronounRetryCorrection?
    let flatRetryCapability: HyMT2FlatPronounRetryCapability?
    let fallback: HyMT2AssessedOutput?
}

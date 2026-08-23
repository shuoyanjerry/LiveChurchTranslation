import Foundation
import TranslationAPI

struct HyMT2TranslationExecutor: Sendable {
    let configuration: HyMT2Configuration
    let transport: any LlamaServerTransport
    let attemptObserver: any HyMT2AttemptObserving
    let pronounTraceObserver: any HyMT2PronounTraceObserving
    let pronounDiagnosticObserver: any HyMT2PronounDiagnosticObserving

    func translate(
        _ input: HyMT2TranslationInput,
        endpoint: LlamaServerEndpoint,
        requestID: UUID
    ) async throws -> HyMT2AssessedOutput {
        let prepared = try prepare(input, requestID: requestID)
        let first = try await observedCompletion(
            prompt(prepared, strict: false),
            endpoint: endpoint,
            requestID: requestID,
            phase: .initial
        )
        do {
            return try await acceptedTarget(
                first,
                input: prepared,
                requestID: requestID,
                phase: .initial
            )
        } catch let failure as OutputValidationFailure {
            await recordRejection(failure, requestID: requestID, phase: .initial)
            let flatRetryCapability = retryCapability(
                for: first,
                input: prepared,
                failure: failure
            )
            let fallback = HyMT2BestEffortExtractor.assess(
                first,
                failure: failure,
                input: prepared
            )
            return try await strictRetry(
                prepared,
                endpoint: endpoint,
                requestID: requestID,
                pronounCorrection: HyMT2PronounRetryCorrection(
                    issues: failure.issues,
                    plan: prepared.pronounPlan,
                    source: prepared.source
                ),
                flatRetryCapability: flatRetryCapability,
                fallback: fallback
            )
        }
    }

    private func strictRetry(
        _ input: HyMT2PreparedTranslationInput,
        endpoint: LlamaServerEndpoint,
        requestID: UUID,
        pronounCorrection: HyMT2PronounRetryCorrection?,
        flatRetryCapability: HyMT2FlatPronounRetryCapability?,
        fallback: HyMT2AssessedOutput?
    ) async throws -> HyMT2AssessedOutput {
        let output: String
        do {
            output = try await observedCompletion(
                prompt(input, strict: true, pronounCorrection: pronounCorrection),
                endpoint: endpoint,
                requestID: requestID,
                phase: .strictRetry
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if let fallback { return fallback }
            throw error
        }
        do {
            return try await acceptedTarget(
                output,
                input: input,
                requestID: requestID,
                phase: .strictRetry,
                flatRetryCapability: flatRetryCapability
            )
        } catch let failure as OutputValidationFailure {
            await recordRejection(failure, requestID: requestID, phase: .strictRetry)
            if let assessed = HyMT2BestEffortExtractor.assess(
                output,
                failure: failure,
                input: input
            ) {
                guard let fallback else { return assessed }
                return assessed.validationIssueCount <= fallback.validationIssueCount
                    ? assessed
                    : fallback
            }
            if let fallback { return fallback }
            throw HyMT2Error.invalidOutput(failure.issues.map(\.description))
        }
    }

    private func acceptedTarget(
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

    private func prompt(
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

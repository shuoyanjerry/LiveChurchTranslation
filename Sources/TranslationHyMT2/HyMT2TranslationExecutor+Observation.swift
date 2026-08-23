import Foundation

extension HyMT2TranslationExecutor {
    func observedCompletion(
        _ prompt: String,
        endpoint: LlamaServerEndpoint,
        requestID: UUID,
        phase: HyMT2AttemptPhase
    ) async throws -> String {
        do {
            return try await completion(prompt, endpoint: endpoint)
        } catch {
            await record(requestID, phase: phase, outcome: .transportFailed)
            throw error
        }
    }

    func record(
        _ requestID: UUID,
        phase: HyMT2AttemptPhase,
        outcome: HyMT2AttemptOutcome
    ) async {
        await attemptObserver.record(
            HyMT2AttemptObservation(requestID: requestID, phase: phase, outcome: outcome)
        )
    }

    func recordPronouns(
        _ output: HyMT2ValidatedOutput,
        requestID: UUID,
        phase: HyMT2AttemptPhase
    ) async {
        for realization in output.pronounRealizations {
            await pronounTraceObserver.record(
                HyMT2PronounTraceObservation(
                    requestID: requestID,
                    phase: phase,
                    sourceRange: realization.occurrence.sourceRange,
                    resolution: realization.occurrence.resolution,
                    realizationClass: realization.realizationClass
                )
            )
        }
    }

    func recordPronounDiagnostics(
        _ failure: OutputValidationFailure,
        requestID: UUID,
        phase: HyMT2AttemptPhase
    ) async {
        for issue in failure.issues {
            guard let diagnostic = issue.pronounDiagnostic else { continue }
            await pronounDiagnosticObserver.record(
                HyMT2PronounDiagnosticObservation(
                    requestID: requestID,
                    phase: phase,
                    sourceRange: diagnostic.sourceRange,
                    expectedResolution: diagnostic.expectedResolution,
                    observedClass: diagnostic.observedClass
                )
            )
        }
    }

    func recordRejection(
        _ failure: OutputValidationFailure,
        requestID: UUID,
        phase: HyMT2AttemptPhase
    ) async {
        await recordPronounDiagnostics(failure, requestID: requestID, phase: phase)
        await record(requestID, phase: phase, outcome: .validationRejected)
    }

    private func completion(
        _ prompt: String,
        endpoint: LlamaServerEndpoint
    ) async throws -> String {
        do {
            return try await transport.complete(
                LlamaCompletionRequest(
                    prompt: prompt,
                    maximumTokens: configuration.maximumOutputTokens,
                    stopSequences: [HyMT2PromptControlDelimiter.currentSourceClosing]
                ),
                at: endpoint,
                timeout: configuration.requestTimeout
            )
        } catch {
            throw HyMT2ErrorNormalizer.normalized(error)
        }
    }
}

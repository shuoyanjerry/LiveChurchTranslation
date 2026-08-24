extension HyMT2TranslationExecutor {
    func strictRetry(
        _ request: HyMT2StrictRetryRequest
    ) async throws -> HyMT2AssessedOutput {
        let output: String
        do {
            output = try await observedCompletion(
                prompt(
                    request.context.input,
                    strict: true,
                    pronounCorrection: request.pronounCorrection
                ),
                endpoint: request.context.endpoint,
                requestID: request.context.requestID,
                phase: .strictRetry
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if let fallback = request.fallback { return fallback }
            throw error
        }
        return try await assessRetry(output, request: request)
    }

    private func assessRetry(
        _ output: String,
        request: HyMT2StrictRetryRequest
    ) async throws -> HyMT2AssessedOutput {
        do {
            return try await acceptedTarget(
                output,
                input: request.context.input,
                requestID: request.context.requestID,
                phase: .strictRetry,
                flatRetryCapability: request.flatRetryCapability
            )
        } catch let failure as OutputValidationFailure {
            await recordRejection(
                failure,
                requestID: request.context.requestID,
                phase: .strictRetry
            )
            return try await selectedFallback(output: output, failure: failure, request: request)
        }
    }

    private func selectedFallback(
        output: String,
        failure: OutputValidationFailure,
        request: HyMT2StrictRetryRequest
    ) async throws -> HyMT2AssessedOutput {
        let assessed = HyMT2BestEffortExtractor.assess(
            output,
            failure: failure,
            input: request.context.input
        )
        if let assessed {
            guard let fallback = request.fallback else { return assessed }
            return assessed.preferredBestEffort(over: fallback)
        }
        if let fallback = request.fallback { return fallback }
        guard qualifiesForSafetyFallback(failure, request: request) else {
            throw HyMT2Error.invalidOutput(failure.safeDescriptions)
        }
        return try await safetyFallback(request.context)
    }

    private func qualifiesForSafetyFallback(
        _ failure: OutputValidationFailure,
        request: HyMT2StrictRetryRequest
    ) -> Bool {
        request.context.input.pronounPlan != nil
            && request.fallback == nil
            && !failure.issues.isEmpty
            && failure.issues.allSatisfy(\.isPronounValidationIssue)
    }
}

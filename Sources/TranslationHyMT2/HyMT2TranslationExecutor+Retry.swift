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
            return try selectedFallback(output: output, failure: failure, request: request)
        }
    }

    private func selectedFallback(
        output: String,
        failure: OutputValidationFailure,
        request: HyMT2StrictRetryRequest
    ) throws -> HyMT2AssessedOutput {
        guard
            let assessed = HyMT2BestEffortExtractor.assess(
                output,
                failure: failure,
                input: request.context.input
            )
        else {
            if let fallback = request.fallback { return fallback }
            throw HyMT2Error.invalidOutput(failure.issues.map(\.description))
        }
        guard let fallback = request.fallback else { return assessed }
        return assessed.validationIssueCount <= fallback.validationIssueCount
            ? assessed
            : fallback
    }
}

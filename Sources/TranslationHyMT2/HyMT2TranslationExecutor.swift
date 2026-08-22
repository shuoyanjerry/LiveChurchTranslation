import TranslationAPI

struct HyMT2TranslationExecutor: Sendable {
    let configuration: HyMT2Configuration
    let transport: any LlamaServerTransport

    func translate(
        source: String,
        targetLanguage: String,
        terms: [TranslationTerm],
        context: [TranslationContextEntry],
        endpoint: LlamaServerEndpoint
    ) async throws -> String {
        let first = try await completion(
            prompt(
                source,
                language: targetLanguage,
                terms: terms,
                context: context,
                strict: false
            ),
            endpoint: endpoint
        )
        do {
            return try validate(first, source: source, terms: terms)
        } catch is OutputValidationFailure {
            let retry = try await completion(
                prompt(
                    source,
                    language: targetLanguage,
                    terms: terms,
                    context: context,
                    strict: true
                ),
                endpoint: endpoint
            )
            do {
                return try validate(retry, source: source, terms: terms)
            } catch let failure as OutputValidationFailure {
                throw HyMT2Error.invalidOutput(failure.issues.map(\.description))
            }
        }
    }

    private func prompt(
        _ source: String,
        language: String,
        terms: [TranslationTerm],
        context: [TranslationContextEntry],
        strict: Bool
    ) -> String {
        HyMT2PromptBuilder.prompt(
            source: source,
            targetLanguage: language,
            terms: terms,
            context: context,
            strict: strict
        )
    }

    private func completion(
        _ prompt: String,
        endpoint: LlamaServerEndpoint
    ) async throws -> String {
        do {
            return try await transport.complete(
                LlamaCompletionRequest(
                    prompt: prompt,
                    maximumTokens: configuration.maximumOutputTokens
                ),
                at: endpoint,
                timeout: configuration.requestTimeout
            )
        } catch {
            throw HyMT2ErrorNormalizer.normalized(error)
        }
    }

    private func validate(
        _ output: String,
        source: String,
        terms: [TranslationTerm]
    ) throws -> String {
        try HyMT2OutputValidator.validate(
            output,
            source: source,
            requiredTerms: terms
        )
    }
}

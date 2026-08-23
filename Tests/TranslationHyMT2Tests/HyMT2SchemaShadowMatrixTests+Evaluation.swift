import TranslationAPI
@testable import TranslationHyMT2

extension HyMT2SchemaShadowMatrixTests {
    func evaluateCurrentNegation(
        _ fixture: HyMT2NegationShadowQ4Fixture,
        index: Int,
        plan: HyMT2SchemaShadowPlan,
        transport: HyMT2SchemaShadowTransport,
        endpoint: LlamaServerEndpoint
    ) async -> HyMT2SchemaShadowResult {
        let current: HyMT2NegationShadowPlan
        do {
            current = try HyMT2SchemaShadowCurrentProtocol.negationPlan(fixture, index: index)
        } catch {
            return failedBeforeOutput(plan, variant: .current, code: .currentProtocol)
        }
        return await evaluateCurrent(
            plan: plan,
            prompt: HyMT2SchemaShadowCurrentProtocol.negationPrompt(current),
            transport: transport,
            endpoint: endpoint
        ) { output in
            try HyMT2SchemaShadowCurrentProtocol.parseNegation(output, current: current)
        }
    }

    func evaluateCurrentPronoun(
        _ fixture: HyMT2SchemaShadowPronounFixture,
        index: Int,
        plan: HyMT2SchemaShadowPlan,
        transport: HyMT2SchemaShadowTransport,
        endpoint: LlamaServerEndpoint
    ) async -> HyMT2SchemaShadowResult {
        let current: HyMT2PronounPlan
        do {
            current = try HyMT2SchemaShadowCurrentProtocol.pronounPlan(fixture, index: index)
        } catch {
            return failedBeforeOutput(plan, variant: .current, code: .currentProtocol)
        }
        let prompt = HyMT2SchemaShadowCurrentProtocol.pronounPrompt(
            current,
            source: fixture.base.source
        )
        return await evaluateCurrent(
            plan: plan,
            prompt: prompt,
            transport: transport,
            endpoint: endpoint
        ) { output in
            try HyMT2SchemaShadowCurrentProtocol.parsePronoun(output, current: current)
        }
    }

    private func evaluateCurrent(
        plan: HyMT2SchemaShadowPlan,
        prompt: String,
        transport: HyMT2SchemaShadowTransport,
        endpoint: LlamaServerEndpoint,
        parse: (String) throws -> HyMT2SchemaShadowSemanticInput
    ) async -> HyMT2SchemaShadowResult {
        let clock = ContinuousClock()
        let started = clock.now
        var outputHash: String?
        do {
            let output = try await currentCompletion(
                prompt: prompt,
                transport: transport,
                endpoint: endpoint
            )
            outputHash = HyMT2NegationShadowFileHasher.sha256UTF8(output)
            try validateCurrentOutput(output, plan: plan, parse: parse)
            return currentResult(
                plan, code: nil, outputHash: outputHash,
                latency: started.duration(to: clock.now)
            )
        } catch let code as HyMT2SchemaShadowFailureCode {
            return currentResult(
                plan, code: code, outputHash: outputHash,
                latency: started.duration(to: clock.now)
            )
        } catch {
            let code: HyMT2SchemaShadowFailureCode =
                outputHash == nil
                ? .transport : .currentProtocol
            return currentResult(
                plan, code: code, outputHash: outputHash,
                latency: started.duration(to: clock.now)
            )
        }
    }

    private func validateCurrentOutput(
        _ output: String,
        plan: HyMT2SchemaShadowPlan,
        parse: (String) throws -> HyMT2SchemaShadowSemanticInput
    ) throws {
        let semantic = try parse(output)
        try HyMT2SchemaShadowSemanticOracle.validate(
            target: semantic.target,
            carrier: semantic.carrier,
            tokens: semantic.tokens,
            bindings: semantic.bindings,
            plan: plan
        )
    }

    private func currentCompletion(
        prompt: String,
        transport: HyMT2SchemaShadowTransport,
        endpoint: LlamaServerEndpoint
    ) async throws -> String {
        try await transport.complete(
            LlamaCompletionRequest(
                prompt: prompt,
                maximumTokens: HyMT2NegationShadowQ4Settings.maximumTokens,
                stopSequences: [HyMT2PromptControlDelimiter.currentSourceClosing]
            ),
            at: endpoint,
            timeout: HyMT2NegationShadowQ4Settings.requestTimeout
        )
    }

    private func currentResult(
        _ plan: HyMT2SchemaShadowPlan,
        code: HyMT2SchemaShadowFailureCode?,
        outputHash: String?,
        latency: Duration
    ) -> HyMT2SchemaShadowResult {
        result(
            plan,
            variant: .current,
            outcome: HyMT2SchemaShadowOutcome(
                code: code,
                outputHash: outputHash,
                schemaHash: nil,
                latency: latency
            )
        )
    }

    private func failedBeforeOutput(
        _ plan: HyMT2SchemaShadowPlan,
        variant: HyMT2SchemaShadowVariant,
        code: HyMT2SchemaShadowFailureCode
    ) -> HyMT2SchemaShadowResult {
        result(
            plan, variant: variant,
            outcome: HyMT2SchemaShadowOutcome(
                code: code,
                outputHash: nil,
                schemaHash: nil,
                latency: .zero
            ))
    }

    func result(
        _ plan: HyMT2SchemaShadowPlan,
        variant: HyMT2SchemaShadowVariant,
        outcome: HyMT2SchemaShadowOutcome
    ) -> HyMT2SchemaShadowResult {
        HyMT2SchemaShadowResult(
            fixtureID: plan.fixtureID,
            family: plan.family,
            variant: variant,
            occurrenceCount: plan.occurrences.count,
            status: outcome.code == nil ? .passed : .failed,
            failureCode: outcome.code,
            latencyMilliseconds: milliseconds(outcome.latency),
            outputSHA256: outcome.outputHash,
            schemaSHA256: outcome.schemaHash
        )
    }
}

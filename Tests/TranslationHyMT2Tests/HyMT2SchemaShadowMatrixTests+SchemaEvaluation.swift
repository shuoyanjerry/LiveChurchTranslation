@testable import TranslationHyMT2

extension HyMT2SchemaShadowMatrixTests {
    func evaluateSchema(
        _ plan: HyMT2SchemaShadowPlan,
        transport: HyMT2SchemaShadowTransport,
        endpoint: LlamaServerEndpoint
    ) async throws -> HyMT2SchemaShadowResult {
        let prepared = try preparedSchema(for: plan)
        let clock = ContinuousClock()
        let started = clock.now
        var outputHash: String?
        do {
            let output = try await schemaCompletion(
                plan,
                nonce: prepared.nonce,
                schema: prepared.schema,
                transport: transport,
                endpoint: endpoint
            )
            outputHash = HyMT2NegationShadowFileHasher.sha256UTF8(output)
            try validateSchemaOutput(output, nonce: prepared.nonce, plan: plan)
            return schemaResult(
                plan, code: nil, outputHash: outputHash, schemaHash: prepared.hash,
                latency: started.duration(to: clock.now)
            )
        } catch let code as HyMT2SchemaShadowFailureCode {
            return schemaResult(
                plan, code: code, outputHash: outputHash, schemaHash: prepared.hash,
                latency: started.duration(to: clock.now)
            )
        } catch {
            let code: HyMT2SchemaShadowFailureCode =
                outputHash == nil
                ? .transport : .runtimeOutput
            return schemaResult(
                plan, code: code, outputHash: outputHash, schemaHash: prepared.hash,
                latency: started.duration(to: clock.now)
            )
        }
    }

    private func preparedSchema(
        for plan: HyMT2SchemaShadowPlan
    ) throws -> HyMT2SchemaShadowPreparedSchema {
        let nonce = randomNonce()
        let schema = try HyMT2SchemaShadowSchemaBuilder.envelope(
            nonce: nonce,
            occurrences: plan.occurrences
        )
        let hash = HyMT2SchemaShadowHash.sha256(
            try HyMT2SchemaShadowSchemaBuilder.encoded(schema)
        )
        return HyMT2SchemaShadowPreparedSchema(nonce: nonce, schema: schema, hash: hash)
    }

    private func schemaCompletion(
        _ plan: HyMT2SchemaShadowPlan,
        nonce: String,
        schema: HyMT2SchemaShadowSchema,
        transport: HyMT2SchemaShadowTransport,
        endpoint: LlamaServerEndpoint
    ) async throws -> String {
        try await transport.completeSchema(
            HyMT2SchemaShadowSchemaRequest(
                prompt: plan.prompt,
                maximumTokens: HyMT2NegationShadowQ4Settings.maximumTokens,
                stop: [HyMT2PromptControlDelimiter.currentSourceClosing],
                schema: schema,
                nonce: nonce
            ),
            at: endpoint,
            timeout: HyMT2NegationShadowQ4Settings.requestTimeout
        )
    }

    private func validateSchemaOutput(
        _ output: String,
        nonce: String,
        plan: HyMT2SchemaShadowPlan
    ) throws {
        let parsed = try HyMT2SchemaShadowParser.envelope(
            output,
            nonce: nonce,
            occurrences: plan.occurrences
        )
        let tokens = Dictionary(
            uniqueKeysWithValues: plan.occurrences.map {
                ($0.identifier, $0.placeholder)
            }
        )
        try HyMT2SchemaShadowSemanticOracle.validate(
            target: parsed.target,
            carrier: parsed.targetTemplate,
            tokens: tokens,
            bindings: parsed.bindings,
            plan: plan
        )
    }

    private func schemaResult(
        _ plan: HyMT2SchemaShadowPlan,
        code: HyMT2SchemaShadowFailureCode?,
        outputHash: String?,
        schemaHash: String,
        latency: Duration
    ) -> HyMT2SchemaShadowResult {
        result(
            plan,
            variant: .schema,
            outcome: HyMT2SchemaShadowOutcome(
                code: code,
                outputHash: outputHash,
                schemaHash: schemaHash,
                latency: latency
            )
        )
    }
}

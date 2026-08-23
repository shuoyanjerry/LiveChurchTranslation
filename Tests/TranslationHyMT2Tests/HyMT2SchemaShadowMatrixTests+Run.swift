import TranslationAPI
@testable import TranslationHyMT2

extension HyMT2SchemaShadowMatrixTests {
    func runMatrix(
        transport: HyMT2SchemaShadowTransport,
        endpoint: LlamaServerEndpoint
    ) async throws -> [HyMT2SchemaShadowResult] {
        var results = try await runNegation(transport: transport, endpoint: endpoint)
        results += try await runPronoun(transport: transport, endpoint: endpoint)
        return results
    }

    private func runNegation(
        transport: HyMT2SchemaShadowTransport,
        endpoint: LlamaServerEndpoint
    ) async throws -> [HyMT2SchemaShadowResult] {
        var results: [HyMT2SchemaShadowResult] = []
        for (index, fixture) in HyMT2SchemaShadowFixtures.negation.enumerated() {
            let plan = try HyMT2SchemaShadowPlanBuilder.negation(fixture, index: index)
            for variant in variantOrder(index) {
                try Task.checkCancellation()
                switch variant {
                case .current:
                    results.append(
                        await evaluateCurrentNegation(
                            fixture,
                            index: index,
                            plan: plan,
                            transport: transport,
                            endpoint: endpoint
                        )
                    )
                case .schema:
                    results.append(
                        try await evaluateSchema(plan, transport: transport, endpoint: endpoint)
                    )
                }
            }
        }
        return results
    }

    private func runPronoun(
        transport: HyMT2SchemaShadowTransport,
        endpoint: LlamaServerEndpoint
    ) async throws -> [HyMT2SchemaShadowResult] {
        var results: [HyMT2SchemaShadowResult] = []
        let offset = HyMT2SchemaShadowFixtures.negation.count
        for (index, fixture) in HyMT2SchemaShadowFixtures.pronoun.enumerated() {
            let plan = try HyMT2SchemaShadowPlanBuilder.pronoun(fixture, index: index)
            for variant in variantOrder(index + offset) {
                try Task.checkCancellation()
                switch variant {
                case .current:
                    results.append(
                        await evaluateCurrentPronoun(
                            fixture,
                            index: index,
                            plan: plan,
                            transport: transport,
                            endpoint: endpoint
                        )
                    )
                case .schema:
                    results.append(
                        try await evaluateSchema(plan, transport: transport, endpoint: endpoint)
                    )
                }
            }
        }
        return results
    }

    private func variantOrder(_ index: Int) -> [HyMT2SchemaShadowVariant] {
        index.isMultiple(of: 2) ? [.current, .schema] : [.schema, .current]
    }
}

import Testing
@testable import TranslationHyMT2

extension HyMT2NegationShadowQ4MatrixTests {
    func runMatrix(
        transport: HyMT2NegationShadowQ4Transport,
        endpoint: LlamaServerEndpoint
    ) async throws -> [HyMT2NegationShadowQ4Result] {
        var results: [HyMT2NegationShadowQ4Result] = []
        for (index, fixture) in HyMT2NegationShadowQ4Fixtures.all.enumerated() {
            for encoding in encodingOrder(index) {
                try Task.checkCancellation()
                let plan = try fixture.plan(encoding: encoding, index: index)
                results.append(
                    await evaluate(
                        fixture,
                        plan: plan,
                        transport: transport,
                        endpoint: endpoint
                    )
                )
            }
        }
        return results
    }

    func recordFailures(_ results: [HyMT2NegationShadowQ4Result]) {
        for result in results where result.status == .failed {
            let code = result.failureCode ?? "neg.shadow.transport"
            Issue.record("Q4 shadow \(result.fixtureID)/\(result.encoding): \(code)")
        }
    }

    private func encodingOrder(_ index: Int) -> [HyMT2NegationShadowEncoding] {
        index.isMultiple(of: 2)
            ? [.englishNot, .originalCue]
            : [.originalCue, .englishNot]
    }

    private func evaluate(
        _ fixture: HyMT2NegationShadowQ4Fixture,
        plan: HyMT2NegationShadowPlan,
        transport: HyMT2NegationShadowQ4Transport,
        endpoint: LlamaServerEndpoint
    ) async -> HyMT2NegationShadowQ4Result {
        let clock = ContinuousClock()
        let started = clock.now
        let outcome: (HyMT2NegationShadowQ4Status, String?)
        var outputSHA256: String?
        do {
            let output = try await completion(plan, transport: transport, endpoint: endpoint)
            outputSHA256 = HyMT2NegationShadowFileHasher.sha256UTF8(output)
            let parsed = try HyMT2NegationMarkerShadowParser.parse(output, plan: plan)
            try HyMT2NegationShadowSemanticOracle.validate(
                rawOutput: output,
                parsed: parsed,
                plan: plan,
                fixture: fixture
            )
            outcome = (.passed, nil)
        } catch let failure as HyMT2NegationShadowFailure {
            outcome = (.failed, "neg.shadow." + failure.category.rawValue)
        } catch let failure as HyMT2NegationShadowSemanticFailure {
            outcome = (.failed, semanticCode(failure))
        } catch {
            outcome =
                outputSHA256 == nil
                ? (.failed, "neg.shadow.transport")
                : (.failed, "neg.shadow.runtime.output")
        }
        return result(
            fixture,
            plan: plan,
            outcome: outcome,
            outputSHA256: outputSHA256,
            latency: started.duration(to: clock.now)
        )
    }

    private func completion(
        _ plan: HyMT2NegationShadowPlan,
        transport: HyMT2NegationShadowQ4Transport,
        endpoint: LlamaServerEndpoint
    ) async throws -> String {
        try await transport.complete(
            LlamaCompletionRequest(
                prompt: HyMT2NegationMarkerShadowPrompt.make(plan),
                maximumTokens: HyMT2NegationShadowQ4Settings.maximumTokens,
                stopSequences: [HyMT2PromptControlDelimiter.currentSourceClosing]
            ),
            at: endpoint,
            timeout: HyMT2NegationShadowQ4Settings.requestTimeout
        )
    }

    private func semanticCode(_ failure: HyMT2NegationShadowSemanticFailure) -> String {
        switch failure {
        case .anchorMissing: "neg.shadow.semantic.anchor"
        case .occurrenceMismatch: "neg.shadow.semantic.occurrence"
        }
    }

    private func result(
        _ fixture: HyMT2NegationShadowQ4Fixture,
        plan: HyMT2NegationShadowPlan,
        outcome: (HyMT2NegationShadowQ4Status, String?),
        outputSHA256: String?,
        latency: Duration
    ) -> HyMT2NegationShadowQ4Result {
        HyMT2NegationShadowQ4Result(
            fixtureID: fixture.identifier,
            encoding: plan.encoding.rawValue,
            occurrenceCount: plan.occurrences.count,
            status: outcome.0,
            failureCode: outcome.1,
            latencyMilliseconds: milliseconds(latency),
            outputSHA256: outputSHA256
        )
    }

    private func milliseconds(_ duration: Duration) -> Double {
        let value =
            Double(duration.components.seconds) * 1_000
            + Double(duration.components.attoseconds) / 1e15
        return (value * 1_000).rounded() / 1_000
    }
}

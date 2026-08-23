import Foundation
@testable import TranslationHyMT2

extension HyMT2SchemaShadowMatrixTests {
    func enforceSchemaProbe(
        transport: HyMT2SchemaShadowTransport,
        endpoint: LlamaServerEndpoint
    ) async throws -> HyMT2SchemaShadowProbeResult {
        let nonce = randomNonce()
        let schema = try HyMT2SchemaShadowSchemaBuilder.probe(nonce: nonce)
        let schemaHash = HyMT2SchemaShadowHash.sha256(
            try HyMT2SchemaShadowSchemaBuilder.encoded(schema)
        )
        let prompt = "Return the single JSON object required by the response schema."
        guard !prompt.contains(nonce) else {
            throw HyMT2SchemaShadowFailureCode.probeFailed
        }
        let clock = ContinuousClock()
        let started = clock.now
        do {
            let output = try await transport.completeSchema(
                HyMT2SchemaShadowSchemaRequest(
                    prompt: prompt,
                    maximumTokens: 128,
                    stop: [],
                    schema: schema,
                    nonce: nonce
                ),
                at: endpoint,
                timeout: HyMT2NegationShadowQ4Settings.requestTimeout
            )
            try HyMT2SchemaShadowParser.probe(output, nonce: nonce)
            return HyMT2SchemaShadowProbeResult(
                status: .passed,
                failureCode: nil,
                latencyMilliseconds: milliseconds(started.duration(to: clock.now)),
                outputSHA256: HyMT2NegationShadowFileHasher.sha256UTF8(output),
                schemaSHA256: schemaHash
            )
        } catch {
            throw HyMT2SchemaShadowFailureCode.probeFailed
        }
    }

    func randomNonce() -> String {
        String(format: "%016llX", UInt64.random(in: .min ... .max))
            + String(format: "%016llX", UInt64.random(in: .min ... .max))
    }

    func milliseconds(_ duration: Duration) -> Double {
        let value =
            Double(duration.components.seconds) * 1_000
            + Double(duration.components.attoseconds) / 1e15
        return (value * 1_000).rounded() / 1_000
    }
}

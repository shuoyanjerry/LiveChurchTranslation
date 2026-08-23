import Foundation
import Testing
@testable import TranslationHyMT2

@Suite("Hy-MT2 public constrained-decoding A/B")
struct HyMT2SchemaShadowMatrixTests {
    @Test(
        "compares current markers with fail-closed JSON Schema envelopes",
        .enabled(
            if: ProcessInfo.processInfo.environment["HYMT_SCHEMA_SHADOW_Q4_MATRIX"] == "1",
            "Requires an explicit public-only Q4 schema-shadow opt in."
        )
    )
    func qualifiesPublicMatrix() async throws {
        let environment = try HyMT2SchemaShadowEnvironment.load(
            ProcessInfo.processInfo.environment
        )
        let run = try await execute(environment)
        let ordered = run.results.sorted {
            ($0.family.rawValue, $0.fixtureID, $0.variant.rawValue)
                < ($1.family.rawValue, $1.fixtureID, $1.variant.rawValue)
        }
        let report = HyMT2SchemaShadowReport(
            environment: environment,
            configurationSHA256: try HyMT2SchemaShadowConfigurationIdentity.sha256(),
            probe: run.probe,
            results: ordered
        )
        try HyMT2SchemaShadowReportWriter.write(report, to: environment.reportURL)
        recordFailures(ordered)
    }

    func recordFailures(_ results: [HyMT2SchemaShadowResult]) {
        for result in results where result.status == .failed {
            let code = result.failureCode?.rawValue ?? "runtime.output"
            let identity = "\(result.family.rawValue)/\(result.fixtureID)/\(result.variant.rawValue)"
            Issue.record("Schema shadow \(identity): \(code)")
        }
    }
}

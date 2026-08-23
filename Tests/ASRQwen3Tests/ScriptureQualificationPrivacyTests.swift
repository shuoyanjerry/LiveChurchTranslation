import Foundation
import ScriptureQualificationSupport
import Testing
import TranslationHyMT2

@Suite("Scripture aggregate-only report")
struct ScriptureQualificationPrivacyTests {
    @Test("report encoding cannot retain references or hypotheses")
    func reportOmitsExpressiveText() throws {
        let metric = try ScriptureQualificationMetric.measure(
            reference: "SENSITIVE_REFERENCE_SENTINEL",
            hypothesis: "SENSITIVE_HYPOTHESIS_SENTINEL",
            lane: .englishASR
        )
        var accumulator = ScriptureQualificationAccumulator()
        accumulator.append(
            contentsOf: [
                .success(
                    partition: .development,
                    lane: .englishASR,
                    metric: metric,
                    runtimeSeconds: 1
                )
            ]
        )
        let data = try encode(fixtureReport(aggregates: accumulator.aggregates()))
        let encoded = try #require(String(data: data, encoding: .utf8))

        #expect(!encoded.contains("SENSITIVE_REFERENCE_SENTINEL"))
        #expect(!encoded.contains("SENSITIVE_HYPOTHESIS_SENTINEL"))
    }

    @Test("HyMT validation details collapse to fixed non-expressive codes")
    func translationFailureCodeOmitsSensitiveSuffix() {
        let sentinel = "SENSITIVE_TERM_SENTINEL"
        let code = HyMT2SafeFailureCode.make(
            HyMT2Error.invalidOutput(["missing required term: \(sentinel)"])
        )

        #expect(code == "hymt.strict.term")
        #expect(!code.contains(sentinel))
    }

    @Test("writer creates a 0600 report atomically and refuses overwrite")
    func writerIsOwnerOnlyAndNoOverwrite() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "scripture-report-test-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let reportURL = root.appendingPathComponent(
            ".artifacts/scripture-qualification-reports/aggregate.json"
        )
        let report = fixtureReport(aggregates: [])

        try ScriptureQualificationReportWriter.write(
            report,
            to: reportURL,
            workspaceRoot: root
        )
        let attributes = try FileManager.default.attributesOfItem(atPath: reportURL.path)
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        #expect(throws: ScriptureModelQualificationError.reportWriteFailed) {
            try ScriptureQualificationReportWriter.write(
                report,
                to: reportURL,
                workspaceRoot: root
            )
        }
    }

    private func fixtureReport(
        aggregates: [ScriptureQualificationAggregate]
    ) -> ScriptureModelQualificationReport {
        ScriptureModelQualificationReport(
            schemaVersion: 1,
            corpusID: "fixture-corpus",
            manifestSHA256: String(repeating: "a", count: 64),
            generatedAt: Date(timeIntervalSince1970: 0),
            policy: .fixed(phase: .development),
            gatePolicyRevision: ScriptureQualificationGatePolicy.revision,
            qualified: false,
            providers: [],
            declarations: [],
            items: [],
            pairs: [],
            aggregates: aggregates,
            failures: [],
            gates: []
        )
    }

    private func encode(_ report: ScriptureModelQualificationReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(report)
    }
}

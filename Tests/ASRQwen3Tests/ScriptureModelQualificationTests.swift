import Foundation
import ScriptureQualificationSupport
import Testing

@Suite("Scripture production-model qualification")
struct ScriptureModelQualificationTests {
    @Test(
        "runs production ASR and bidirectional translation without expressive output",
        .enabled(
            if: ScriptureModelQualificationConfiguration.isRequested(
                ProcessInfo.processInfo.environment
            ),
            "Requires the ephemeral Scripture environment and production model paths."
        )
    )
    func qualifiesVerifiedCorpus() async throws {
        let configuration = try ScriptureModelQualificationConfiguration.load(
            environment: ProcessInfo.processInfo.environment
        )
        let report = try await ScriptureProductionQualificationRunner().run(
            configuration: configuration
        )
        try ScriptureQualificationReportWriter.write(
            report,
            to: configuration.reportURL,
            workspaceRoot: configuration.workspaceRoot
        )
        let reportSHA = try ScriptureQualificationSHA256.hash(fileAt: configuration.reportURL)

        print("SCRIPTURE_QUALIFICATION_REPORT_SHA256=\(reportSHA)")
        print("SCRIPTURE_QUALIFICATION_PHASE=\(configuration.phase.rawValue)")
        print("SCRIPTURE_QUALIFICATION_PAIRS=\(report.pairs.count)")
        print("SCRIPTURE_QUALIFICATION_FAILURES=\(report.totalFailures)")
        print("SCRIPTURE_QUALIFICATION_QUALIFIED=\(report.qualified)")
        #expect(report.schemaVersion == 2)
        #expect(report.aggregates.count == ScriptureQualificationLane.allCases.count)
        #expect(report.aggregates.allSatisfy { $0.attemptCount > 0 })
        #expect(report.failures.count == report.totalFailures)
        #expect(report.totalFailures == 0)
        if configuration.phase == .sealed {
            #expect(report.gates.count == ScriptureQualificationLane.allCases.count)
            #expect(report.qualified)
        } else {
            #expect(report.gates.isEmpty)
            #expect(!report.qualified)
        }
    }
}

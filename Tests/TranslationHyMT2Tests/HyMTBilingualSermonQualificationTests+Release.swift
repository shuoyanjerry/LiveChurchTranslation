import Foundation
import TranslationQualificationSupport
@testable import TranslationHyMT2

extension HyMTBilingualSermonQualificationTests {
    func finalizeEvidence(
        _ input: HyMTQualificationReleaseInput
    ) throws {
        let evidence = try makeReleaseEvidence(input)
        let configuration = input.configuration
        let executionGuard = input.executionGuard
        let report = evidence.report
        let gateFailure = try releaseGateFailure(
            report,
            expectation: evidence.expectation,
            configuration: configuration,
            executionGuard: executionGuard
        )
        let reportURL = try writeDiagnostic(
            report,
            expectation: evidence.expectation,
            configuration: configuration,
            executionGuard: executionGuard
        )
        let reportHash = try TranslationQualificationSHA256.hash(fileAt: reportURL)
        print("DIAGNOSTIC_REPORT_SHA256=\(reportHash)")
        print("RELEASE_READY=\(gateFailure == nil ? "true" : "false")")
        if let gateFailure {
            print("RELEASE_GATE_FAILURE=quality-or-review-gates-failed")
            throw gateFailure
        }
    }

    private func makeReleaseEvidence(
        _ input: HyMTQualificationReleaseInput
    ) throws -> HyMTReleaseEvidence {
        let provider = TranslationQualificationProvider(
            identifier: input.provider.identifier,
            modelRevision: HyMTQualificationConfiguration.modelRevision,
            modelSHA256: input.provenance.model.sha256,
            runtimeRevision: HyMTQualificationConfiguration.runtimeRevision,
            runtimeSHA256: input.provenance.helper.sha256,
            settings: input.configuration.providerSettings
        )
        let environment = HyMTQualificationHostEnvironment.capture(
            backgroundLoad: input.configuration.backgroundLoad
        )
        let expectation = try input.executionGuard.releaseExpectation(
            corpus: input.corpus,
            provider: provider,
            environment: environment,
            attempts: input.attempts
        )
        let report = try TranslationQualificationReportBuilder.build(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            corpus: input.corpus,
            provider: provider,
            environment: environment,
            executionProvenance: input.provenance,
            attempts: input.attempts
        )
        return HyMTReleaseEvidence(report: report, expectation: expectation)
    }

    private func releaseGateFailure(
        _ report: TranslationQualificationReport,
        expectation: TranslationReleaseExpectation,
        configuration: HyMTQualificationConfiguration,
        executionGuard: HyMTQualificationExecutionGuard
    ) throws -> (any Error)? {
        try executionGuard.revalidate(configuration: configuration)
        let failure: (any Error)?
        do {
            try TranslationQualificationReleaseGate.requireReleaseReadyGates(
                report,
                expectation: expectation
            )
            failure = nil
        } catch {
            failure = error
        }
        try executionGuard.revalidate(configuration: configuration)
        return failure
    }

    private func writeDiagnostic(
        _ report: TranslationQualificationReport,
        expectation: TranslationReleaseExpectation,
        configuration: HyMTQualificationConfiguration,
        executionGuard: HyMTQualificationExecutionGuard
    ) throws -> URL {
        try executionGuard.revalidate(configuration: configuration)
        let reportURL = try TranslationQualificationReportWriter.writePrivate(
            report,
            releaseExpectation: expectation,
            workspaceRoot: configuration.workspaceRoot,
            filename: configuration.reportFilename
        )
        try executionGuard.revalidate(configuration: configuration)
        return reportURL
    }
}

struct HyMTQualificationReleaseInput {
    let configuration: HyMTQualificationConfiguration
    let corpus: TranslationQualificationCorpus
    let provider: HyMT2TranslationProvider
    let provenance: TranslationExecutionProvenance
    let attempts: [TranslationQualificationAttempt]
    let executionGuard: HyMTQualificationExecutionGuard
}

private struct HyMTReleaseEvidence {
    let report: TranslationQualificationReport
    let expectation: TranslationReleaseExpectation
}

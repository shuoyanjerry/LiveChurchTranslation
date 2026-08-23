import Foundation
import Testing
import TranslationQualificationSupport
@testable import TranslationHyMT2

@MainActor
@Suite("Hy-MT2 negation diagnostic replay")
struct HyMTNegationDiagnosticRunnerTests {
    @Test func replaysOnlyNegationFailuresWithFrozenApprovedContext() async throws {
        let segments = try HyMTNegationDiagnosticTestFixture.segments()
        let attempts = HyMTNegationDiagnosticTestFixture.classifiedAttempts(segments)
        let result = try await replay(segments: segments, attempts: attempts)
        try verify(result.report, segments: segments, prompts: result.prompts)
        try verifyOutputPrivacy(result)
    }

    private func replay(
        segments: [TranslationQualificationSegment],
        attempts: [TranslationQualificationAttempt]
    ) async throws -> ReplayResult {
        let recorder = HyMTQualificationAttemptRecorder()
        let base = FakeLlamaServerTransport(
            responses: [.success("The work can stop."), .success("The work cannot stop.")]
        )
        let transport = HyMTNegationRecordingTransport(base: base)
        let model = try TemporaryGGUF()
        let server = FakeLlamaServerController()
        let configuration = HyMT2TestSupport.configuration()
        let provider = HyMT2TranslationProvider(
            configuration: configuration,
            server: server,
            transport: transport,
            endpointFactory: { HyMT2TestSupport.endpoint },
            attemptObserver: recorder
        )
        try await provider.loadModel(at: model.fileURL)
        let result = try await HyMTNegationDiagnosticRunner(
            provider: provider,
            transport: transport,
            recorder: recorder,
            providerConfiguration: configuration
        ).run(
            segments: segments,
            manifestSHA256: String(repeating: "a", count: 64),
            classified: HyMTNegationClassifiedEvidence(
                attempts: attempts,
                reportSHA256: String(repeating: "b", count: 64)
            )
        )
        await provider.shutdown()
        return ReplayResult(
            report: result.report,
            protectedModelOutputs: result.protectedModelOutputs,
            prompts: await base.completionRequests().map(\.prompt)
        )
    }

    private func verify(
        _ report: HyMTNegationDiagnosticReport,
        segments: [TranslationQualificationSegment],
        prompts: [String]
    ) throws {
        let entry = try #require(report.entries.first)
        #expect(report.entries.count == 1)
        #expect(entry.segmentID == segments[2].id)
        #expect(entry.attemptCount == 2)
        #expect(entry.sourceCueClasses == [.compoundBu])
        #expect(entry.referenceCueClass == .lexical)
        #expect(entry.terminalFailureCode == "none")
        #expect(entry.attempts[0].targetCueClass == .none)
        #expect(entry.attempts[0].validationIssueCodes.contains(.missingNegation))
        #expect(entry.attempts[1].targetCueClass == .explicit)
        #expect(entry.attempts[1].validationIssueCodes.isEmpty)
        #expect(prompts.count == 2)
        #expect(prompts.allSatisfy { $0.contains("Prior approved context.") })
        #expect(prompts.allSatisfy { !$0.contains(segments[2].referenceEnglish) })
    }

    private func verifyOutputPrivacy(_ result: ReplayResult) throws {
        #expect(result.protectedModelOutputs.count == 2)
        let data = try HyMTNegationDiagnosticPrivacyGuard.encoded(
            result.report,
            sensitiveTexts: result.protectedModelOutputs
        )
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(result.protectedModelOutputs.allSatisfy { !text.contains($0) })
    }

    private struct ReplayResult {
        let report: HyMTNegationDiagnosticReport
        let protectedModelOutputs: [String]
        let prompts: [String]
    }
}

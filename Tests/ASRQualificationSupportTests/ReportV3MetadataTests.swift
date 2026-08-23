import ASRQualificationSupport
import Foundation
import Testing

@Suite struct ReportV3MetadataTests {
    @Test func rejectsInvalidManifestHashProviderLaneAndSettingValue() {
        #expect(throws: ASRQualificationReportV3Error.invalidQualificationManifestSHA256) {
            _ = try metadataReport(manifestSHA256: String(repeating: "A", count: 64))
        }
        let lane = ASRQualificationProviderMetadataV3(
            name: "FixtureProvider", lane: "benchmarkHelper",
            modelRevision: "model", runtimeRevision: "runtime"
        )
        #expect(throws: ASRQualificationReportV3Error.invalidProviderLane("benchmarkHelper")) {
            _ = try metadataReport(provider: lane)
        }
        let setting = ASRQualificationProviderMetadataV3(
            name: "FixtureProvider", modelRevision: "model", runtimeRevision: "runtime",
            settings: ["threads": " \n"]
        )
        #expect(throws: ASRQualificationReportV3Error.invalidSettingValue("threads")) {
            _ = try metadataReport(provider: setting)
        }
    }

    @Test func rejectsInvalidAndMismatchedSourceDuration() {
        #expect(throws: ASRQualificationReportV3Error.invalidSourceAudioSeconds(clipID: "clip")) {
            _ = try metadataReport(clips: [reportInput(sourceAudioSeconds: -.infinity)])
        }
        #expect(throws: ASRQualificationReportV3Error.sourceAudioSecondsMismatch(clipID: "clip")) {
            _ = try metadataReport(clips: [reportInput(sourceAudioSeconds: 1)])
        }
    }

    @Test func rejectsReferenceElapsedAndWhitespaceFailurePayload() {
        let wrongReference = reportFixture(reference: "她")
        #expect(
            throws: ASRQualificationReportV3Error.referenceSHA256Mismatch(
                clipID: "clip", expected: referenceHash("他"), actual: referenceHash("她")
            )
        ) {
            _ = try metadataReport(
                manifest: wrongReference.manifest, clips: [wrongReference.input])
        }
        let elapsed = reportAttempt(testSegment(), elapsedSeconds: .infinity)
        #expect(
            throws: ASRQualificationReportV3Error.invalidElapsedSeconds(
                clipID: "clip", sequence: 1
            )
        ) {
            _ = try metadataReport(clips: [reportInput(attempts: [elapsed])])
        }
        let whitespace = reportAttempt(
            testSegment(), status: .failure, hypothesis: nil, failureCode: " \n"
        )
        #expect(
            throws: ASRQualificationReportV3Error.failedAttemptMissingFailureCode(
                clipID: "clip", sequence: 1
            )
        ) {
            _ = try metadataReport(clips: [reportInput(attempts: [whitespace])])
        }
    }

    @Test func allFailuresHaveNoSuccessfulLatencyPercentiles() throws {
        let failure = reportAttempt(
            testSegment(), elapsedSeconds: 2, status: .failure,
            hypothesis: nil, failureCode: "decode"
        )
        let report = try metadataReport(clips: [reportInput(attempts: [failure])])
        let clipTiming = report.clips[0].timing

        #expect(clipTiming.successfulAttemptLatencyP50Seconds == nil)
        #expect(clipTiming.successfulAttemptLatencyP95Seconds == nil)
        #expect(clipTiming.allAttemptLatencyP50Seconds == 2)
        #expect(clipTiming.allAttemptLatencyP95Seconds == 2)
        #expect(clipTiming.withinThreeSecondsRate == 0)
        #expect(report.aggregate.timing.successfulAttemptLatencyP50Seconds == nil)
        #expect(report.aggregate.timing.successfulAttemptLatencyP95Seconds == nil)
    }
}

private func metadataReport(
    manifestSHA256: String = testHash,
    manifest: ASRQualificationManifestV2? = nil,
    provider: ASRQualificationProviderMetadataV3 = reportProvider,
    clips: [ASRQualificationClipEvaluationInputV3]? = nil
) throws -> ASRQualificationReportV3 {
    let fixture = reportFixture()
    return try ASRQualificationReportV3Builder().build(
        qualificationManifestSHA256: manifestSHA256,
        manifest: manifest ?? fixture.manifest,
        provider: provider,
        environment: reportEnvironment,
        clips: clips ?? [fixture.input]
    )
}

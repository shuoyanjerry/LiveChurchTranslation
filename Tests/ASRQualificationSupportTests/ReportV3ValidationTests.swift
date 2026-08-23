import ASRQualificationSupport
import Foundation
import Testing

@Suite struct ReportV3ValidationTests {
    @Test func rejectsMissingUnexpectedAndDuplicateClips() {
        let valid = reportFixture()
        expectReportError(
            .clipSetMismatch(expected: ["clip"], actual: []),
            manifest: valid.manifest,
            clips: []
        )
        expectReportError(
            .duplicateClipID("clip"),
            manifest: valid.manifest,
            clips: [valid.input, valid.input]
        )
    }

    @Test func rejectsChangedSegmentDefinitions() {
        let fixture = reportFixture()
        let changed = testSegment(reason: "changed-boundary-reason")
        let input = reportInput(segments: [changed], attempts: [reportAttempt(changed)])
        expectReportError(
            .segmentDefinitionsMismatch(clipID: "clip"),
            manifest: fixture.manifest,
            clips: [input]
        )
    }

    @Test func rejectsAttemptCountAndSequenceMismatch() {
        let fixture = reportFixture()
        expectReportError(
            .attemptCountMismatch(clipID: "clip", expected: 1, actual: 0),
            manifest: fixture.manifest,
            clips: [reportInput(attempts: [])]
        )
        let wrongSequence = reportAttempt(testSegment(), sequence: 2)
        expectReportError(
            .attemptSequenceMismatch(clipID: "clip", expected: 1, actual: 2),
            manifest: fixture.manifest,
            clips: [reportInput(attempts: [wrongSequence])]
        )
    }

    @Test func rejectsAttemptSampleCountAndPCMIdentityMismatch() {
        let fixture = reportFixture()
        let wrongCount = reportAttempt(testSegment(), inputSampleCount: 3)
        expectReportError(
            .attemptInputSampleCountMismatch(
                clipID: "clip", sequence: 1, expected: 2, actual: 3
            ),
            manifest: fixture.manifest,
            clips: [reportInput(attempts: [wrongCount])]
        )
        let wrongHash = reportAttempt(testSegment(), pcmSHA256: String(repeating: "b", count: 64))
        expectReportError(
            .attemptPCMHashMismatch(
                clipID: "clip", sequence: 1, expected: testHash,
                actual: String(repeating: "b", count: 64)
            ),
            manifest: fixture.manifest,
            clips: [reportInput(attempts: [wrongHash])]
        )
    }

    @Test func attemptStatusPayloadsFailClosed() {
        let fixture = reportFixture()
        let cases: [(ASRQualificationAttemptV3, ASRQualificationReportV3Error)] = [
            (
                reportAttempt(testSegment(), hypothesis: nil),
                .successfulAttemptMissingHypothesis(clipID: "clip", sequence: 1)
            ),
            (
                reportAttempt(testSegment(), failureCode: "unexpected"),
                .successfulAttemptHasFailureCode(clipID: "clip", sequence: 1)
            ),
            (
                reportAttempt(testSegment(), status: .failure, hypothesis: "leak", failureCode: "x"),
                .failedAttemptHasHypothesis(clipID: "clip", sequence: 1)
            ),
            (
                reportAttempt(testSegment(), status: .failure, hypothesis: nil, failureCode: nil),
                .failedAttemptMissingFailureCode(clipID: "clip", sequence: 1)
            ),
        ]
        for (attempt, error) in cases {
            expectReportError(
                error, manifest: fixture.manifest,
                clips: [reportInput(attempts: [attempt])])
        }
    }
}

func reportFixture(
    id: String = "clip",
    reference: String = "他"
) -> (manifest: ASRQualificationManifestV2, input: ASRQualificationClipEvaluationInputV3) {
    let segment = testSegment()
    let clip = testClip(id: id, referenceSHA256: referenceHash("他"), segments: [segment])
    return (
        testManifest(clips: [clip]),
        reportInput(
            id: id, reference: reference, segments: [segment],
            attempts: [reportAttempt(segment)])
    )
}

func reportInput(
    id: String = "clip",
    reference: String = "他",
    sourceAudioSeconds: Double = 4.0 / 16_000,
    segments: [ASRQualificationSegmentV2] = [testSegment()],
    attempts: [ASRQualificationAttemptV3]? = nil
) -> ASRQualificationClipEvaluationInputV3 {
    ASRQualificationClipEvaluationInputV3(
        id: id,
        referenceText: reference,
        sourceAudioSeconds: sourceAudioSeconds,
        segments: segments,
        attempts: attempts ?? segments.map { reportAttempt($0) }
    )
}

func reportAttempt(
    _ segment: ASRQualificationSegmentV2,
    sequence: Int? = nil,
    inputSampleCount: Int? = nil,
    pcmSHA256: String? = nil,
    elapsedSeconds: Double = 0.25,
    status: ASRQualificationAttemptStatusV3 = .success,
    hypothesis: String? = "他",
    failureCode: String? = nil
) -> ASRQualificationAttemptV3 {
    ASRQualificationAttemptV3(
        sequence: sequence ?? segment.sequence,
        inputSampleCount: inputSampleCount
            ?? segment.validSampleCount + segment.syntheticPaddingSamples,
        pcmSHA256: pcmSHA256 ?? segment.pcmSHA256,
        elapsedSeconds: elapsedSeconds,
        status: status,
        hypothesis: hypothesis,
        failureCode: failureCode
    )
}

func referenceHash(_ text: String) -> String { sha256(Data(text.utf8)) }

func expectReportError(
    _ expected: ASRQualificationReportV3Error,
    manifest: ASRQualificationManifestV2,
    clips: [ASRQualificationClipEvaluationInputV3]
) {
    do {
        _ = try ASRQualificationReportV3Builder().build(
            qualificationManifestSHA256: testHash,
            manifest: manifest,
            provider: reportProvider,
            environment: reportEnvironment,
            clips: clips
        )
        Issue.record("Expected \(expected)")
    } catch let error as ASRQualificationReportV3Error {
        #expect(error == expected)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

let reportProvider = ASRQualificationProviderMetadataV3(
    name: "FixtureProvider", modelRevision: "model", runtimeRevision: "runtime"
)

let reportEnvironment = ASRQualificationEnvironmentV3(
    os: "test", hardware: "test", architecture: "arm64",
    buildConfiguration: "debug", repositoryRevision: "revision",
    repositoryDirty: false, backgroundLoadNote: "idle"
)

import ASRQualificationSupport
import Foundation

enum QwenQualificationTestFixtures {
    static let zeroHash = String(repeating: "0", count: 64)

    static func manifest(
        referenceManifestSHA256: String = zeroHash,
        referenceText: String = "他"
    ) -> ASRQualificationManifestV2 {
        ASRQualificationManifestV2(
            schemaVersion: 2,
            corpusID: "fixture-corpus",
            provenance: ASRQualificationProvenanceV2(
                sourceVADReportSHA256: zeroHash,
                sourceVADStrategy: "webrtcStable",
                sourceVADConfigurationSHA256: zeroHash,
                sourceReferenceManifestSHA256: referenceManifestSHA256,
                sourceCorpusManifestSHA256: zeroHash,
                generatorRevision: "fixture-revision"
            ),
            clips: [
                ASRQualificationClipV2(
                    id: "fixture-clip",
                    audioSHA256: zeroHash,
                    sampleRate: 100,
                    totalSamples: 1_000,
                    referenceSHA256: QwenQualificationHashing.sha256(Data(referenceText.utf8)),
                    allowsHypothesisEdgeInsertions: true,
                    segments: segments
                )
            ]
        )
    }

    static let segments = [
        ASRQualificationSegmentV2(
            sequence: 1,
            startSample: 0,
            endSample: 100,
            validSampleCount: 100,
            syntheticPaddingSamples: 0,
            endReason: "softSilence",
            pcmSHA256: String(repeating: "1", count: 64)
        ),
        ASRQualificationSegmentV2(
            sequence: 2,
            startSample: 100,
            endSample: 200,
            validSampleCount: 100,
            syntheticPaddingSamples: 0,
            endReason: "maximumBoundary",
            pcmSHA256: String(repeating: "2", count: 64)
        ),
    ]

    static let environment = ASRQualificationEnvironmentV3(
        os: "macOS fixture",
        hardware: "Mac fixture",
        architecture: "arm64",
        buildConfiguration: "debug",
        repositoryRevision: "fixture-revision",
        repositoryDirty: true,
        backgroundLoadNote: "Uncontrolled fixture load."
    )
}

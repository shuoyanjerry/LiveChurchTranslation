import Foundation
import Testing

@Suite("V3 selected WebRTC static evidence gates")
struct V3SelectedVADStaticGateTests {
    @Test func selectedConfigurationAndProductionSourcesArePinned() throws {
        let workspace = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        ).resolvingSymlinksInPath()
        let production = try V3SelectedVADSourceFingerprints.production(workspaceRoot: workspace)
        let harness = try V3SelectedVADSourceFingerprints.harness(workspaceRoot: workspace)
        let configuration = try V3SelectedVADHashing.canonicalDigest(
            V3SelectedVADConfigurationEvidence.selected()
        )
        #expect(production.fileCount == 59)
        #expect(production.sha256 == V3SelectedVADPolicy.productionSourceSHA256)
        #expect(harness.fileCount > 20)
        #expect(V3SelectedVADManifestValidator.isDigest(harness.sha256))
        #expect(V3SelectedVADManifestValidator.isDigest(configuration))
    }

    @Test func privacyValidatorRejectsPrivateIdentityAndPathFields() throws {
        let safe = Data("{\"logicalItemOrdinal\":1,\"trackOrdinal\":1}".utf8)
        try V3SelectedVADReportCodec.validatePrivacy(safe, forbiddenValues: ["private-item-id"])
        #expect(throws: V3SelectedVADError.privacyFailure) {
            try V3SelectedVADReportCodec.validatePrivacy(
                Data("{\"logicalItemOrdinal\":1,\"note\":\"private-item-id\"}".utf8),
                forbiddenValues: ["private-item-id"]
            )
        }
        #expect(throws: V3SelectedVADError.privacyFailure) {
            try V3SelectedVADReportCodec.validatePrivacy(
                Data("{\"relativeWAVPath\":\"hidden.wav\"}".utf8),
                forbiddenValues: []
            )
        }
    }

    @Test func aggregatesKeepFailuresInTheSceneDenominator() {
        let attempts = [
            fixtureAttempt(item: 1, track: 1, scene: .genuineChurchSermon, success: true),
            fixtureAttempt(item: 2, track: 1, scene: .genuineChurchSermon, success: false),
            fixtureAttempt(item: 3, track: 1, scene: .scriptedOrNarrationProgram, success: true),
        ]
        let aggregate = V3SelectedVADAggregateBuilder.make(attempts)
        #expect(aggregate.overall.trackAttemptCount == 3)
        #expect(aggregate.overall.successCount == 2)
        #expect(aggregate.overall.failureCount == 1)
        #expect(aggregate.genuineChurchSermons.trackAttemptCount == 2)
        #expect(aggregate.scriptedOrNarrationPrograms.trackAttemptCount == 1)
    }

    private func fixtureAttempt(
        item: Int,
        track: Int,
        scene: V3SelectedVADSceneClass,
        success: Bool
    ) -> V3SelectedVADAttempt {
        V3SelectedVADAttempt(
            logicalItemOrdinal: item,
            trackOrdinal: track,
            sceneClass: scene,
            sourceWAVSHA256: String(repeating: "a", count: 64),
            sourceWAVByteCount: 2_044,
            exactSampleFrames: 1_000,
            audioSeconds: 0.0625,
            resetBeforeTrack: true,
            endOfStreamAfterTrack: true,
            success: success,
            failureCode: success ? nil : .processingFailure,
            metrics: success ? fixtureMetrics() : nil
        )
    }

    private func fixtureMetrics() -> V3SelectedVADTrackMetrics {
        V3SelectedVADTrackMetrics(
            productionVoiceSignatureSHA256: String(repeating: "b", count: 64),
            shadowVoiceSignatureSHA256: String(repeating: "b", count: 64),
            productionShadowParity: true,
            speechStartedCount: 1,
            segmentCount: 1,
            underTwoSecondsCount: 1,
            reasonCounts: ["endOfStream": 1],
            segmentDurationSamples: [1_000],
            candidateReachedCounts: [:],
            candidateResolutionCounts: [:]
        )
    }
}

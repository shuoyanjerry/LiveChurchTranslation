import Foundation
import Testing

@Suite("Candidate-pause adversarial report mutations")
struct CandidatePauseMutationTests {
    @Test func rejectsResolutionBeforeLastReachedEvent() async throws {
        let source = try await CandidatePauseMutationFixture.validDocument()
        let events = source.files[0].events
        let reordered = [events[0], events[3], events[1], events[2]].enumerated().map {
            CandidatePauseMutationFixture.ordinal($0.element, $0.offset + 1)
        }
        try expectRejected(CandidatePauseMutationFixture.document(source, events: reordered))
    }

    @Test func rejectsNonFrameAlignedThresholdGapMutation() async throws {
        let source = try await CandidatePauseMutationFixture.validDocument()
        var events = source.files[0].events
        events[1] = CandidatePauseMutationFixture.shiftedCandidateEnd(events[1], by: 1)
        try expectRejected(CandidatePauseMutationFixture.document(source, events: events))
    }

    @Test func acceptsSingleRawSpeechBlipBetweenCheckpoints() async throws {
        var capture = try CandidatePauseSyntheticCapture()
        try await capture.send(amplitude: 0.1, milliseconds: 300)
        try await capture.send(amplitude: 0, milliseconds: 260)
        try await capture.send(amplitude: 0.1, milliseconds: 20)
        try await capture.send(amplitude: 0, milliseconds: 140)
        let file = try await capture.finish()
        let document = CandidatePauseSyntheticDocument.make(file: file)
        try CandidatePauseDocumentValidator.validate(document)
        let candidates = file.events.compactMap(\.reached).map(\.candidateEndSourceSample)
        #expect(candidates.count == 3)
        #expect(candidates[1] - candidates[0] == 1_120)
    }

    @Test func rejectsResolvedEventAndResolutionClockMismatch() async throws {
        let source = try await CandidatePauseMutationFixture.validDocument()
        let original = source.files[0].events
        let value = original[0].resolution
        let shifted = CandidatePauseResolutionRecord(
            kind: value.kind,
            observedAtSourceSample: value.observedAtSourceSample + 1,
            observedAtSeconds: Double(value.observedAtSourceSample + 1) / 16_000,
            segmentEndReason: value.segmentEndReason
        )
        let events = original.map { CandidatePauseMutationFixture.resolution($0, shifted) }
        try expectRejected(CandidatePauseMutationFixture.document(source, events: events))
    }

    @Test func rejectsSegmentResolutionDifferentFromFinalBoundary() async throws {
        let source = try await CandidatePauseMutationFixture.validDocument()
        let original = source.files[0].events
        let value = original[0].resolution
        let changed = CandidatePauseResolutionRecord(
            kind: "segmentEnded",
            observedAtSourceSample: value.observedAtSourceSample,
            observedAtSeconds: value.observedAtSeconds,
            segmentEndReason: "softSilence"
        )
        let events = original.map { CandidatePauseMutationFixture.resolution($0, changed) }
        try expectRejected(CandidatePauseMutationFixture.document(source, events: events))
    }

    @Test func rejectsReachedKindAndDetachedBoundary() async throws {
        let source = try await CandidatePauseMutationFixture.validDocument()
        var events = source.files[0].events
        events[0] = CandidatePauseMutationFixture.kind(events[0], "resolved")
        try expectRejected(CandidatePauseMutationFixture.document(source, events: events))
        let detached = source.files[0].events.map {
            CandidatePauseMutationFixture.boundaryReason($0, "softSilence")
        }
        try expectRejected(CandidatePauseMutationFixture.document(source, events: detached))
    }

    @Test func companionAndProductionSourceBundlesAreIndependentlyBound() throws {
        let workspace = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let first = try CandidatePauseHashing.boundSourceFingerprints(workspaceRoot: workspace)
        let second = try CandidatePauseHashing.boundSourceFingerprints(workspaceRoot: workspace)
        #expect(first == second)
        #expect(first.production.sha256 != first.companion.sha256)
        #expect(first.production.fileCount > 0)
        #expect(first.companion.fileCount > 0)
    }

    @Test func rejectsUppercaseOrNonHexProvenanceDigest() async throws {
        let source = try await CandidatePauseMutationFixture.validDocument()
        let uppercase = CandidatePauseMutationFixture.provenanceDigest(
            source,
            digest: String(repeating: "A", count: 64)
        )
        try expectRejected(uppercase)
        let nonHex = CandidatePauseMutationFixture.provenanceDigest(
            source,
            digest: String(repeating: "g", count: 64)
        )
        try expectRejected(nonHex)
    }

    @Test func rejectsForgedFileAndBoundaryMetadata() async throws {
        let source = try await CandidatePauseMutationFixture.validDocument()
        try expectRejected(
            CandidatePauseMutationFixture.fileAudioSeconds(
                source,
                value: source.files[0].audioSeconds + 0.001
            )
        )
        try expectRejected(
            CandidatePauseMutationFixture.finalizedBoundary(
                source,
                endSample: Int(source.files[0].totalSamples) + 1
            )
        )
        try expectRejected(
            CandidatePauseMutationFixture.finalizedBoundary(
                source,
                endedAtSeconds: source.files[0].finalizedBoundaries[0].endedAtSeconds + 0.001
            )
        )
        try expectRejected(
            CandidatePauseMutationFixture.finalizedBoundary(source, reason: "invented")
        )
        try expectRejected(
            CandidatePauseMutationFixture.finalizedBoundary(
                source,
                pcmSHA256: String(repeating: "A", count: 64)
            )
        )
    }

    private func expectRejected(_ document: CandidatePauseBenchmarkDocument) throws {
        #expect(throws: CandidatePauseBenchmarkError.self) {
            try CandidatePauseDocumentValidator.validate(document)
        }
    }

}

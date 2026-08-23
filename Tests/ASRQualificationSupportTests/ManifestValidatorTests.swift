import ASRQualificationSupport
import Testing

@Suite struct ManifestValidatorTests {
    @Test func acceptsOverlappingPreRollWithContinuousSequences() throws {
        let first = testSegment(sequence: 1, start: 0, end: 4, valid: 4)
        let overlapping = testSegment(sequence: 2, start: 2, end: 6, valid: 4)
        let manifest = testManifest(
            clips: [testClip(totalSamples: 8, segments: [first, overlapping])]
        )

        try ASRQualificationManifestValidator().validate(manifest)
    }

    @Test func rejectsEmptyCorpusAndClipCollection() {
        expectError(.emptyCorpusID, manifest: testManifest(corpusID: " \n "))
        expectError(.emptyClips, manifest: testManifest(clips: []))
    }

    @Test func rejectsIncompleteProvenance() {
        let emptyStrategy = ASRQualificationProvenanceV2(
            sourceVADReportSHA256: testHash,
            sourceVADStrategy: " ",
            sourceVADConfigurationSHA256: testHash,
            sourceReferenceManifestSHA256: testHash,
            sourceCorpusManifestSHA256: testHash,
            generatorRevision: "revision"
        )
        let badHash = ASRQualificationProvenanceV2(
            sourceVADReportSHA256: "A" + String(repeating: "a", count: 63),
            sourceVADStrategy: "strategy",
            sourceVADConfigurationSHA256: testHash,
            sourceReferenceManifestSHA256: testHash,
            sourceCorpusManifestSHA256: testHash,
            generatorRevision: "revision"
        )

        expectError(
            .emptyProvenanceField("sourceVADStrategy"),
            manifest: testManifest(provenance: emptyStrategy)
        )
        expectError(
            .invalidSHA256(path: "provenance.sourceVADReportSHA256"),
            manifest: testManifest(provenance: badHash)
        )
    }

    @Test func rejectsDuplicateOrBlankClipIDs() {
        let duplicate = testManifest(
            clips: [testClip(id: "same"), testClip(id: "same")]
        )

        expectError(.duplicateClipID("same"), manifest: duplicate)
        expectError(
            .invalidClipID(index: 0),
            manifest: testManifest(clips: [testClip(id: "")])
        )
    }

    @Test func rejectsInvalidClipMetadataAndHashes() {
        expectError(
            .invalidSampleRate(clipID: "clip", value: 0),
            manifest: testManifest(clips: [testClip(sampleRate: 0)])
        )
        expectError(
            .invalidTotalSamples(clipID: "clip", value: 0),
            manifest: testManifest(clips: [testClip(totalSamples: 0)])
        )
        expectError(
            .invalidSHA256(path: "clip.audioSHA256"),
            manifest: testManifest(clips: [testClip(audioSHA256: "abc")])
        )
        expectError(
            .invalidSHA256(path: "clip.referenceSHA256"),
            manifest: testManifest(clips: [testClip(referenceSHA256: "ABC")])
        )
    }
}

@Suite struct SegmentManifestValidatorTests {
    @Test func rejectsEmptySegmentsAndNoncontinuousSequences() {
        expectError(
            .emptySegments(clipID: "clip"),
            manifest: testManifest(clips: [testClip(segments: [])])
        )
        let repeated = [testSegment(sequence: 1), testSegment(sequence: 1, start: 1, end: 3)]
        expectError(
            .invalidSequence(clipID: "clip", expected: 2, actual: 1),
            manifest: testManifest(clips: [testClip(segments: repeated)])
        )
        expectError(
            .invalidSequence(clipID: "clip", expected: 1, actual: 0),
            manifest: testManifest(clips: [testClip(segments: [testSegment(sequence: 0)])])
        )
    }

    @Test func rejectsSequenceGapsAndNonIncreasingAbsoluteBounds() {
        let gap = [
            testSegment(sequence: 1),
            testSegment(sequence: 3, start: 1, end: 3),
        ]
        expectError(
            .invalidSequence(clipID: "clip", expected: 2, actual: 3),
            manifest: testManifest(clips: [testClip(segments: gap)])
        )
        let reorderedStart = [
            testSegment(sequence: 1, start: 1, end: 3),
            testSegment(sequence: 2, start: 0, end: 4, valid: 4),
        ]
        expectError(
            .nonIncreasingSegmentOrder(clipID: "clip", sequence: 2),
            manifest: testManifest(clips: [testClip(segments: reorderedStart)])
        )
        let stalledEnd = [
            testSegment(sequence: 1, start: 0, end: 3, valid: 3),
            testSegment(sequence: 2, start: 1, end: 3, valid: 2),
        ]
        expectError(
            .nonIncreasingSegmentOrder(clipID: "clip", sequence: 2),
            manifest: testManifest(clips: [testClip(segments: stalledEnd)])
        )
    }

    @Test func rejectsEveryOutOfBoundsRangeWithoutClamping() {
        let invalid = [
            testSegment(start: -1, end: 2, valid: 3),
            testSegment(start: 2, end: 2, valid: 0),
            testSegment(start: 3, end: 5, valid: 2),
        ]
        for segment in invalid {
            expectError(
                .invalidSegmentRange(clipID: "clip", sequence: 1),
                manifest: testManifest(clips: [testClip(segments: [segment])])
            )
        }
    }

    @Test func rejectsInvalidSampleAccountingAndOverflow() {
        let mismatch = testSegment(start: 0, end: 3, valid: 2, padding: 0)
        let overflow = testSegment(
            start: 0,
            end: 2,
            valid: 2,
            padding: .max
        )
        for segment in [mismatch, overflow] {
            expectError(
                .invalidSampleAccounting(clipID: "clip", sequence: 1),
                manifest: testManifest(clips: [testClip(segments: [segment])])
            )
        }
    }

    @Test func rejectsBlankReasonAndInvalidPCMHash() {
        expectError(
            .emptyEndReason(clipID: "clip", sequence: 1),
            manifest: testManifest(clips: [testClip(segments: [testSegment(reason: " ")])])
        )
        expectError(
            .invalidSHA256(path: "clip.segments[1].pcmSHA256"),
            manifest: testManifest(
                clips: [testClip(segments: [testSegment(pcmSHA256: "bad")])]
            )
        )
    }
}

private func expectError(
    _ expected: ASRQualificationError,
    manifest: ASRQualificationManifestV2
) {
    do {
        try ASRQualificationManifestValidator().validate(manifest)
        Issue.record("Expected \(expected)")
    } catch let error as ASRQualificationError {
        #expect(error == expected)
    } catch {
        Issue.record("Unexpected error: \(error)")
    }
}

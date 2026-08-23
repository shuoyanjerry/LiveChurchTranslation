import ASRQualificationSupport
import Foundation
import Testing

@Suite struct WAVLoaderResourceSafetyTests {
    private let loader = ASRQualificationWAVLoader()

    @Test func rejectsEveryNonFiniteFloatEncodingBeforePCMHashing() throws {
        for sample in [Float.nan, Float.infinity, -Float.infinity] {
            let wav = floatWAV([0, sample])
            let clip = testClip(audioSHA256: sha256(wav), totalSamples: 2)

            expectLoaderError(
                .nonFiniteFloatSample(clipID: "clip", sequence: 1, sourceSample: 1),
                wav: wav,
                clip: clip
            )
        }
    }

    @Test func rejectsPaddingAboveDocumentedLimit() {
        let maximum = ASRQualificationResourceLimits.maximumSyntheticPaddingSamples
        let segment = testSegment(padding: maximum + 1)
        let manifest = testManifest(clips: [testClip(segments: [segment])])

        expectManifestError(
            .syntheticPaddingLimitExceeded(
                clipID: "clip",
                sequence: 1,
                value: maximum + 1,
                maximum: maximum
            ),
            manifest: manifest
        )
    }

    @Test func rejectsLoadedPCMAboveDocumentedLimit() {
        let maximum = ASRQualificationResourceLimits.maximumLoadedSegmentSamples
        let segment = testSegment(end: maximum + 1, valid: maximum + 1)
        let manifest = testManifest(
            clips: [testClip(totalSamples: maximum + 1, segments: [segment])]
        )

        expectManifestError(
            .loadedSampleLimitExceeded(
                clipID: "clip",
                sequence: 1,
                value: maximum + 1,
                maximum: maximum
            ),
            manifest: manifest
        )
    }

    @Test func loaderRejectsLimitBeforeOpeningSourceOrAllocatingPCM() {
        let maximum = ASRQualificationResourceLimits.maximumSyntheticPaddingSamples
        let segment = testSegment(padding: maximum + 1)
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        do {
            _ = try loader.load(clip: testClip(segments: [segment]), from: missingURL)
            Issue.record("Expected pre-I/O resource-limit rejection")
        } catch let error as ASRQualificationError {
            guard case .syntheticPaddingLimitExceeded = error else {
                Issue.record("Unexpected ASR qualification error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func rejectsCumulativeOverlappingPCMThatCouldAmplifyMemory() {
        let segmentLength = 1_900_000
        let segments = (0..<9).map { index in
            testSegment(
                sequence: index + 1,
                start: index,
                end: segmentLength + index,
                valid: segmentLength
            )
        }
        let clip = testClip(
            totalSamples: segmentLength + segments.count,
            segments: segments
        )

        expectManifestError(
            .loadedClipSampleLimitExceeded(
                clipID: "clip",
                maximum: ASRQualificationResourceLimits.maximumLoadedClipSamples
            ),
            manifest: testManifest(clips: [clip])
        )
    }

    private func expectManifestError(
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

    private func expectLoaderError(
        _ expected: ASRQualificationError,
        wav: Data,
        clip: ASRQualificationClipV2
    ) {
        do {
            let url = try temporaryWAV(wav)
            defer { try? FileManager.default.removeItem(at: url) }
            _ = try loader.load(clip: clip, from: url)
            Issue.record("Expected \(expected)")
        } catch let error as ASRQualificationError {
            #expect(error == expected)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

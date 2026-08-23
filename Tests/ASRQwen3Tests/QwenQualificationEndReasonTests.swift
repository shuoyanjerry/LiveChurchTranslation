import ASRQualificationSupport
import ASRQwen3
import Foundation
import Testing
import VADAPI

@Suite("Qwen qualification segment mapping")
struct QwenQualificationEndReasonTests {
    @Test("maps every frozen VAD end reason")
    func mapsKnownReasons() throws {
        #expect(try QwenQualificationEndReason.map("trailingSilence") == .trailingSilence)
        #expect(try QwenQualificationEndReason.map("softSilence") == .softSilence)
        #expect(try QwenQualificationEndReason.map("maximumBoundary") == .maximumBoundary)
        #expect(try QwenQualificationEndReason.map("maximumDuration") == .maximumDuration)
        #expect(try QwenQualificationEndReason.map("endOfStream") == .endOfStream)
    }

    @Test("fails closed for an unknown end reason")
    func rejectsUnknownReason() {
        #expect(throws: QwenQualificationSegmentError.unknownEndReason("futureReason")) {
            try QwenQualificationEndReason.map("futureReason")
        }
    }

    @Test("aborts qualification before provider timing when an end reason is unknown")
    func recorderFailsClosedBeforeProviderCall() async {
        let loaded = ASRQualificationLoadedSegment(
            definition: definition(endReason: "futureReason"),
            samples: [0.25]
        )

        await #expect(
            throws: QwenQualificationSegmentError.unknownEndReason("futureReason")
        ) {
            try await QwenQualificationAttemptRecorder.transcribe(
                loaded,
                sampleRate: 16_000,
                provider: Qwen3ASRProvider()
            )
        }
    }

    @Test("preserves absolute timestamps and includes verified padding in model input")
    func createsAbsoluteSpeechSegment() throws {
        let definition = ASRQualificationSegmentV2(
            sequence: 7,
            startSample: 8_000,
            endSample: 16_000,
            validSampleCount: 8_000,
            syntheticPaddingSamples: 2,
            endReason: "softSilence",
            pcmSHA256: QwenQualificationTestFixtures.zeroHash
        )
        let loaded = ASRQualificationLoadedSegment(
            definition: definition,
            samples: Array(repeating: 0.25, count: 8_002)
        )

        let speech = try QwenQualificationEndReason.speechSegment(
            loaded: loaded,
            sampleRate: 16_000
        )

        #expect(speech.sequenceNumber == 7)
        #expect(speech.samples.count == 8_002)
        #expect(speech.startedAt == .seconds(0.5))
        #expect(speech.endedAt == .seconds(1))
        #expect(speech.endReason == .softSilence)
    }

    @Test("rejects clip IDs that could escape the WAV directory")
    func rejectsUnsafeWAVPath() {
        #expect(throws: QwenQualificationSegmentError.unsafeClipID("../secret")) {
            try QwenQualificationWAVLocator.url(
                for: "../secret",
                in: URL(fileURLWithPath: "/wav")
            )
        }
    }

    private func definition(endReason: String) -> ASRQualificationSegmentV2 {
        ASRQualificationSegmentV2(
            sequence: 1,
            startSample: 0,
            endSample: 1,
            validSampleCount: 1,
            syntheticPaddingSamples: 0,
            endReason: endReason,
            pcmSHA256: QwenQualificationTestFixtures.zeroHash
        )
    }
}

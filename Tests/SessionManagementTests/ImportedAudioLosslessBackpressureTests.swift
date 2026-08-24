import AudioCaptureAPI
import SessionManagementAPI
import Testing

@Suite struct ImportedAudioLosslessBackpressureTests {
    @Test func importBeyondLiveFanoutCapacityRemainsLossless() async throws {
        let frameCount = AudioFrameStream.defaultBacklogFrameLimit + 512
        let frames = Self.frames(count: frameCount)
        let harness = SessionTestHarness(
            audioProcessingDelay: .microseconds(100),
            emitsOnlyOnFlush: true,
            audioFrames: frames,
            sessionKind: .importedAudio
        )

        _ = try await harness.run(timeout: .seconds(20))

        #expect(await harness.recordingStore.recordedFrames() == frames)
        #expect(await harness.processor.frames() == frames)
        #expect((await harness.asr.receivedRequests()).count == 1)
        #expect((await harness.translator.receivedRequests()).isEmpty)
        #expect((await harness.coordinator.currentSnapshot()).finalizationOutcome == .saved)
    }

    private static func frames(count: Int) -> [AudioFrame] {
        (0..<count).map { index in
            AudioFrame(
                samples: SessionTestHarness.audioFrame.samples,
                sampleRate: 16_000,
                channelCount: 1,
                timestamp: .milliseconds(Int64(index * 20))
            )
        }
    }
}

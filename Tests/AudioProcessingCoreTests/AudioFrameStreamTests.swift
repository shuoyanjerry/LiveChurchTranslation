import AudioCaptureAPI
import Testing

@Suite struct AudioFrameStreamTests {
    @Test func retainsBurstsBeyondTheFormerCaptureLimit() async throws {
        let pair = AudioFrameStream.makeBounded()
        let frames = (0..<256).map { index in
            AudioFrame(
                samples: [Float(index)],
                sampleRate: 16_000,
                channelCount: 1,
                timestamp: .milliseconds(index)
            )
        }

        for frame in frames {
            guard case .enqueued = pair.continuation.yield(frame) else {
                Issue.record("A live capture frame was not enqueued")
                return
            }
        }
        pair.continuation.finish()

        var received: [AudioFrame] = []
        for try await frame in pair.stream {
            received.append(frame)
        }
        #expect(received == frames)
    }

    @Test func reportsOverflowWithoutReplacingAlreadyQueuedFrames() async throws {
        let pair = AudioFrameStream.makeBounded(frameLimit: 2)
        let frames = (0..<3).map { index in
            AudioFrame(
                samples: [Float(index)],
                sampleRate: 16_000,
                channelCount: 1,
                timestamp: .milliseconds(index)
            )
        }

        #expect(isEnqueued(pair.continuation.yield(frames[0])))
        #expect(isEnqueued(pair.continuation.yield(frames[1])))
        guard case .dropped(let dropped) = pair.continuation.yield(frames[2]) else {
            Issue.record("Expected the bounded stream to report overflow")
            return
        }
        #expect(dropped == frames[2])
        pair.continuation.finish()

        var received: [AudioFrame] = []
        for try await frame in pair.stream {
            received.append(frame)
        }
        #expect(received == Array(frames.prefix(2)))
    }

    private func isEnqueued(_ result: AudioFrameStream.Stream.Continuation.YieldResult) -> Bool {
        if case .enqueued = result { return true }
        return false
    }
}

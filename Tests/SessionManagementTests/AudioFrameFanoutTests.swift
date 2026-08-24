import AudioCaptureAPI
@testable import SessionManagement
import Testing

@Suite struct AudioFrameFanoutTests {
    @Test func overflowRetainsQueuedFramesAndSurfacesAPipelineFailure() async {
        let fanout = AudioFrameFanout(frameLimit: 2)
        let source = AudioFrameStream.Stream.makeStream(bufferingPolicy: .unbounded)
        let frames = (0..<3).map { index in
            AudioFrame(
                samples: [Float(index)],
                sampleRate: 16_000,
                channelCount: 1,
                timestamp: .milliseconds(index)
            )
        }
        frames.forEach { source.continuation.yield($0) }
        source.continuation.finish()

        await #expect(throws: AudioPipelineFailure.self) {
            try await fanout.forward(source.stream)
        }

        var received: [AudioFrame] = []
        var surfacedFailure = false
        do {
            for try await frame in fanout.recording {
                received.append(frame)
            }
        } catch is AudioPipelineFailure {
            surfacedFailure = true
        } catch {
            Issue.record("Expected the bounded fanout failure")
        }
        #expect(received == Array(frames.prefix(2)))
        #expect(surfacedFailure)
    }
}

import AudioCaptureAPI
@testable import AudioFileAVFoundation
import Testing

@MainActor
@Suite struct FileAudioCaptureProviderTests {
    @Test func decodesStereoWAVWithInterleavingAndTimestamps() async throws {
        let fixture = try AudioFileTestFixture()
        defer { fixture.remove() }
        let expected: [Float] = [0.1, -0.1, 0.2, -0.2, 0.3, -0.3, 0.4, -0.4, 0.5, -0.5]
        let url = try fixture.audioFile(
            extension: "wav",
            sampleRate: 8_000,
            channelCount: 2,
            interleavedSamples: expected
        )
        let provider = FileAudioCaptureProvider(url: url)

        let frames = try await collect(
            from: provider,
            request: AudioCaptureRequest(bufferDuration: .microseconds(250))
        )

        #expect(frames.map(\.channelCount) == [2, 2, 2])
        #expect(frames.map(\.frameCount) == [2, 2, 1])
        #expect(frames.map(\.timestamp) == [.zero, .microseconds(250), .microseconds(500)])
        expectSamples(frames.flatMap(\.samples), equalTo: expected)
    }

    @Test func decodesCAFWithoutChangingSamples() async throws {
        let fixture = try AudioFileTestFixture()
        defer { fixture.remove() }
        let expected: [Float] = [-0.75, -0.25, 0, 0.25, 0.75]
        let url = try fixture.audioFile(
            extension: "caf",
            sampleRate: 8_000,
            channelCount: 1,
            interleavedSamples: expected
        )
        let provider = FileAudioCaptureProvider(url: url)

        let frames = try await collect(
            from: provider,
            request: AudioCaptureRequest(bufferDuration: .microseconds(375))
        )

        #expect(frames.map(\.timestamp) == [.zero, .microseconds(375)])
        #expect(frames.allSatisfy { $0.sampleRate == 8_000 })
        expectSamples(frames.flatMap(\.samples), equalTo: expected)
    }

    @Test func stopEndsStreamAndAllowsRestart() async throws {
        let fixture = try AudioFileTestFixture()
        defer { fixture.remove() }
        let url = try fixture.securityScopedURL(
            for: fixture.audioFile(
                extension: "wav",
                sampleRate: 8_000,
                channelCount: 1,
                interleavedSamples: Array(repeating: 0.5, count: 20)
            )
        )
        let provider = FileAudioCaptureProvider(url: url)
        let request = AudioCaptureRequest(bufferDuration: .microseconds(250))
        let stream = try await provider.startCapture(request: request)
        var iterator = stream.makeAsyncIterator()

        #expect(try await iterator.next() != nil)
        await provider.stopCapture()
        #expect(try await iterator.next() == nil)

        let restarted = try await provider.startCapture(request: request)
        var restartedIterator = restarted.makeAsyncIterator()
        #expect(try await restartedIterator.next()?.timestamp == .zero)
        await provider.stopCapture()
    }

    @Test func rejectsConcurrentStartAndUnknownInput() async throws {
        let fixture = try AudioFileTestFixture()
        defer { fixture.remove() }
        let url = try fixture.audioFile(
            extension: "caf",
            sampleRate: 8_000,
            channelCount: 1,
            interleavedSamples: [0, 1]
        )
        let provider = FileAudioCaptureProvider(url: url)
        let stream = try await provider.startCapture(request: AudioCaptureRequest())
        var iterator = stream.makeAsyncIterator()

        await #expect(throws: AudioCaptureError.captureAlreadyRunning) {
            try await provider.startCapture(request: AudioCaptureRequest())
        }
        await provider.stopCapture()
        _ = try await iterator.next()
        await #expect(throws: AudioCaptureError.deviceNotFound(.init(rawValue: "other"))) {
            try await provider.startCapture(
                request: AudioCaptureRequest(deviceID: .init(rawValue: "other"))
            )
        }
    }
}

extension FileAudioCaptureProviderTests {
    @Test func reportsInvalidAudioFile() async throws {
        let fixture = try AudioFileTestFixture()
        defer { fixture.remove() }
        let url = try fixture.invalidFile()
        let provider = FileAudioCaptureProvider(url: url)

        await #expect(throws: FileAudioCaptureError.self) {
            try await FileAudioCaptureProvider.validateSource(at: url)
        }

        await #expect(throws: FileAudioCaptureError.self) {
            try await provider.startCapture(request: AudioCaptureRequest())
        }
    }

    @Test func releasingStreamCancelsCapture() async throws {
        let fixture = try AudioFileTestFixture()
        defer { fixture.remove() }
        let url = try fixture.securityScopedURL(
            for: fixture.audioFile(
                extension: "caf",
                sampleRate: 8_000,
                channelCount: 1,
                interleavedSamples: Array(repeating: 0.25, count: 32)
            )
        )
        let provider = FileAudioCaptureProvider(url: url)
        var abandoned: AsyncThrowingStream<AudioFrame, any Error>? =
            try await provider
            .startCapture(request: AudioCaptureRequest())
        #expect(abandoned != nil)
        abandoned = nil

        var restarted = false
        for _ in 0..<20 where !restarted {
            do {
                _ = try await provider.startCapture(request: AudioCaptureRequest())
                restarted = true
            } catch AudioCaptureError.captureAlreadyRunning {
                await Task.yield()
            }
        }
        #expect(restarted)
        await provider.stopCapture()
    }

    private func collect(
        from provider: FileAudioCaptureProvider,
        request: AudioCaptureRequest
    ) async throws -> [AudioFrame] {
        let stream = try await provider.startCapture(request: request)
        var frames = [AudioFrame]()
        for try await frame in stream { frames.append(frame) }
        return frames
    }

    private func expectSamples(_ actual: [Float], equalTo expected: [Float]) {
        #expect(actual.count == expected.count)
        for (left, right) in zip(actual, expected) {
            #expect(abs(left - right) < 0.000_01)
        }
    }
}

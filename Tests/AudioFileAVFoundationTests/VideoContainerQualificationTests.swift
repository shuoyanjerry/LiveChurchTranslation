@preconcurrency import AVFoundation
import AudioCaptureAPI
@testable import AudioFileAVFoundation
import Testing

@MainActor
@Suite struct VideoContainerQualificationTests {
    @Test(arguments: VideoFixtureContainer.allCases)
    func decodesAudioTrackFromGeneratedVideo(
        container: VideoFixtureContainer
    ) async throws {
        let fixture = try AudioFileTestFixture()
        defer { fixture.remove() }
        let url = try await fixture.videoFile(container: container, includesAudio: true)
        let asset = AVURLAsset(url: url)

        #expect(url.pathExtension == container.rawValue)
        #expect(try await asset.loadTracks(withMediaType: .video).count == 1)
        #expect(try await asset.loadTracks(withMediaType: .audio).count == 1)

        let frames = try await collect(from: FileAudioCaptureProvider(url: url))

        #expect(frames.count > 1)
        #expect(frames.first?.timestamp == .zero)
        #expect(frames.allSatisfy { $0.sampleRate.isFinite && $0.sampleRate > 0 })
        #expect(frames.allSatisfy { $0.channelCount == 1 && $0.frameCount > 0 })
        #expect(zip(frames, frames.dropFirst()).allSatisfy { $0.timestamp < $1.timestamp })
        let samples = frames.flatMap(\.samples)
        #expect(samples.count > 10_000)
        #expect(samples.allSatisfy { $0.isFinite })
        #expect(samples.map(abs).max() ?? 0 > 0.01)
    }

    @Test func validationRejectsGeneratedVideoWithoutAnAudioTrack() async throws {
        let fixture = try AudioFileTestFixture()
        defer { fixture.remove() }
        let url = try await fixture.videoFile(container: .mov, includesAudio: false)
        let asset = AVURLAsset(url: url)

        #expect(try await asset.loadTracks(withMediaType: .video).count == 1)
        #expect(try await asset.loadTracks(withMediaType: .audio).isEmpty)

        do {
            try await FileAudioCaptureProvider.validateSource(at: url)
            Issue.record("Expected source validation to reject a video without an audio track")
        } catch let error as FileAudioCaptureError {
            #expect(error.errorDescription?.isEmpty == false)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func collect(from provider: FileAudioCaptureProvider) async throws -> [AudioFrame] {
        let stream = try await provider.startCapture(
            request: AudioCaptureRequest(bufferDuration: .milliseconds(100))
        )
        var frames = [AudioFrame]()
        for try await frame in stream { frames.append(frame) }
        return frames
    }
}

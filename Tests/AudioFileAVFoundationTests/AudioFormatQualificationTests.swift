import AudioCaptureAPI
@testable import AudioFileAVFoundation
import Testing

@MainActor
@Suite struct AudioFormatQualificationTests {
    @Test(arguments: SpokenAudioFixtureCase.required)
    func decodesGeneratedSpokenAudio(testCase: SpokenAudioFixtureCase) async throws {
        let fixture = try AudioFileTestFixture()
        defer { fixture.remove() }
        let url = try fixture.spokenAudioFile(for: testCase)

        let frames = try await collect(from: FileAudioCaptureProvider(url: url))

        #expect(url.pathExtension == testCase.format.fileExtension)
        #expect(frames.count > 1)
        #expect(frames.first?.timestamp == .zero)
        #expect(frames.allSatisfy { $0.sampleRate.isFinite && $0.sampleRate > 0 })
        #expect(frames.allSatisfy { $0.channelCount == 1 && $0.frameCount > 0 })
        #expect(zip(frames, frames.dropFirst()).allSatisfy { $0.timestamp < $1.timestamp })
        let samples = frames.flatMap(\.samples)
        #expect(samples.count > 4_000)
        #expect(samples.allSatisfy { $0.isFinite })
        #expect(samples.map(abs).max() ?? 0 > 0.001)
    }

    @Test(
        .enabled(
            if: AudioFileTestFixture.canQualifyMP3,
            "afconvert has no MP3 encoder; set AUDIO_IMPORT_MP3_FIXTURE to a rights-safe MP3."
        )
    )
    func decodesMP3WhenQualificationInputIsAvailable() async throws {
        let fixture = try AudioFileTestFixture()
        defer { fixture.remove() }
        let url = try fixture.mp3AudioFile()

        let provider = FileAudioCaptureProvider(url: url)
        let frames = try await collectPrefix(from: provider, maximumFrames: 16)

        #expect(!frames.isEmpty)
        #expect(frames.count <= 16)
        #expect(frames.first?.timestamp == .zero)
        #expect(zip(frames, frames.dropFirst()).allSatisfy { $0.timestamp < $1.timestamp })
        #expect(frames.flatMap(\.samples).contains { abs($0) > 0.001 })
    }

    @Test func requiredMatrixCoversDeclaredContainersAndBothLanguageLanes() {
        let formats = Set(SpokenAudioFixtureCase.required.map(\.format))
        let languages = Set(SpokenAudioFixtureCase.required.map(\.language))

        #expect(formats == [.wav, .aiff, .aifc, .caf, .aac, .m4a, .flac])
        #expect(languages == Set(FixtureLanguage.allCases))
    }

    private func collect(from provider: FileAudioCaptureProvider) async throws -> [AudioFrame] {
        let stream = try await provider.startCapture(
            request: AudioCaptureRequest(bufferDuration: .milliseconds(100))
        )
        var frames = [AudioFrame]()
        for try await frame in stream { frames.append(frame) }
        return frames
    }

    private func collectPrefix(
        from provider: FileAudioCaptureProvider,
        maximumFrames: Int
    ) async throws -> [AudioFrame] {
        let stream = try await provider.startCapture(
            request: AudioCaptureRequest(bufferDuration: .milliseconds(100))
        )
        var frames = [AudioFrame]()
        do {
            for try await frame in stream {
                frames.append(frame)
                if frames.count == maximumFrames { break }
            }
        } catch {
            await provider.stopCapture()
            throw error
        }
        await provider.stopCapture()
        return frames
    }
}

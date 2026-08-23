import ASRQualificationSupport
import Foundation
import Testing

@Suite struct WAVLoaderFailureTests {
    private let loader = ASRQualificationWAVLoader()

    @Test func rejectsWholeFileAudioHashMismatch() throws {
        let wav = floatWAV([0, 0])
        let clip = testClip(audioSHA256: testHash)
        let actual = sha256(wav)

        expectLoaderError(
            .audioSHA256Mismatch(clipID: "clip", expected: testHash, actual: actual),
            wav: wav,
            clip: clip
        )
    }

    @Test func rejectsSampleRateAndTotalSampleMismatch() throws {
        let samples: [Float] = [0, 0]
        let wav = floatWAV(samples)
        let hash = sha256(wav)
        let wrongRate = testClip(audioSHA256: hash, sampleRate: 8_000)
        let wrongTotal = testClip(
            audioSHA256: hash,
            totalSamples: 3,
            segments: [testSegment()]
        )

        expectLoaderError(
            .sampleRateMismatch(clipID: "clip", expected: 8_000, actual: 16_000),
            wav: wav,
            clip: wrongRate
        )
        expectLoaderError(
            .totalSamplesMismatch(clipID: "clip", expected: 3, actual: 2),
            wav: wav,
            clip: wrongTotal
        )
    }

    @Test func rejectsModelPCMHashMismatch() throws {
        let samples: [Float] = [0.25, -0.5]
        let wav = floatWAV(samples)
        let clip = testClip(audioSHA256: sha256(wav), totalSamples: 2)
        let actual = pcmSHA256(samples)

        expectLoaderError(
            .pcmSHA256Mismatch(
                clipID: "clip",
                sequence: 1,
                expected: testHash,
                actual: actual
            ),
            wav: wav,
            clip: clip
        )
    }

    @Test func rejectsStereoAndMalformedWAV() {
        let stereo = floatWAV([0, 0, 0, 0], channels: 2)
        let stereoClip = testClip(
            audioSHA256: sha256(stereo),
            totalSamples: 2
        )
        expectUnsupportedWAV(stereo, clip: stereoClip)

        let malformed = Data("not-wave".utf8)
        let malformedClip = testClip(audioSHA256: sha256(malformed))
        expectUnsupportedWAV(malformed, clip: malformedClip)
    }

    @Test func rejectsOutOfRangeBeforeReadingInsteadOfClamping() throws {
        let wav = floatWAV([0, 0])
        let segment = testSegment(start: 0, end: 3, valid: 3)
        let clip = testClip(
            audioSHA256: sha256(wav),
            totalSamples: 2,
            segments: [segment]
        )
        let url = try temporaryWAV(wav)
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try loader.load(clip: clip, from: url)
            Issue.record("Expected exact range rejection")
        } catch let error as ASRQualificationError {
            #expect(error == .invalidSegmentRange(clipID: "clip", sequence: 1))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func rejectsUnreadableSource() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        do {
            _ = try loader.load(clip: testClip(), from: url)
            Issue.record("Expected source read failure")
        } catch let error as ASRQualificationError {
            #expect(error == .audioReadFailed(url.path))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

extension WAVLoaderFailureTests {
    fileprivate func expectUnsupportedWAV(
        _ wav: Data,
        clip: ASRQualificationClipV2
    ) {
        let url: URL
        do {
            url = try temporaryWAV(wav)
        } catch {
            Issue.record("Could not write fixture: \(error)")
            return
        }
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            _ = try loader.load(clip: clip, from: url)
            Issue.record("Expected WAV format rejection")
        } catch let error as ASRQualificationError {
            guard case .unsupportedWAV = error else {
                Issue.record("Unexpected ASR qualification error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    fileprivate func expectLoaderError(
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

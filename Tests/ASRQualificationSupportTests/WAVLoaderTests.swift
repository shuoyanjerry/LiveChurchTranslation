import ASRQualificationSupport
import Foundation
import Testing

@Suite struct WAVLoaderTests {
    private let loader = ASRQualificationWAVLoader()

    @Test func loadsExactOverlappingAbsoluteFloatRanges() throws {
        let samples: [Float] = [0.125, -0.25, 0.5, -0.75, 1]
        let wav = floatWAV(samples)
        let firstPCM = Array(samples[0..<3])
        let secondPCM = Array(samples[2..<5])
        let segments = [
            testSegment(
                sequence: 1,
                start: 0,
                end: 3,
                valid: 3,
                pcmSHA256: pcmSHA256(firstPCM)
            ),
            testSegment(
                sequence: 2,
                start: 2,
                end: 5,
                valid: 3,
                pcmSHA256: pcmSHA256(secondPCM)
            ),
        ]
        let clip = verifiedClip(wav: wav, totalSamples: samples.count, segments: segments)

        let url = try temporaryWAV(wav)
        defer { try? FileManager.default.removeItem(at: url) }
        let loaded = try loader.load(clip: clip, from: url)

        #expect(loaded.map(\.definition.sequence) == [1, 2])
        #expect(loaded[0].samples == firstPCM)
        #expect(loaded[1].samples == secondPCM)
    }

    @Test func replacesSyntheticTailWithZeroBeforeHashing() throws {
        let source: [Float] = [0.1, 0.2, 0.3, 0.9]
        let modelPCM: [Float] = [0.2, 0.3, 0]
        let segment = testSegment(
            start: 1,
            end: 3,
            valid: 2,
            padding: 1,
            pcmSHA256: pcmSHA256(modelPCM)
        )
        let wav = floatWAV(source)
        let clip = verifiedClip(wav: wav, totalSamples: 4, segments: [segment])

        let url = try temporaryWAV(wav)
        defer { try? FileManager.default.removeItem(at: url) }
        let loaded = try loader.load(clip: clip, from: url)

        #expect(loaded[0].samples == modelPCM)
        #expect(loaded[0].samples != Array(source[1..<4]))
    }

    @Test func convertsPCM16ToModelFloat32Deterministically() throws {
        let integers: [Int16] = [.min, -16_384, 0, .max]
        let modelPCM: [Float] = [-1, -0.5, 0, Float(Int16.max) / 32_768]
        let wav = pcm16WAV(integers)
        let segment = testSegment(
            end: 4,
            valid: 4,
            pcmSHA256: pcmSHA256(modelPCM)
        )
        let clip = verifiedClip(wav: wav, totalSamples: 4, segments: [segment])

        let url = try temporaryWAV(wav)
        defer { try? FileManager.default.removeItem(at: url) }
        let loaded = try loader.load(clip: clip, from: url)

        #expect(loaded[0].samples == modelPCM)
    }

    @Test func acceptsExtensibleMonoFloatWAV() throws {
        let samples: [Float] = [0.25, -0.5]
        let wav = floatWAV(samples, extensible: true)
        let segment = testSegment(pcmSHA256: pcmSHA256(samples))
        let clip = verifiedClip(wav: wav, totalSamples: 2, segments: [segment])

        let url = try temporaryWAV(wav)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(try loader.load(clip: clip, from: url)[0].samples == samples)
    }

    private func verifiedClip(
        wav: Data,
        totalSamples: Int,
        segments: [ASRQualificationSegmentV2]
    ) -> ASRQualificationClipV2 {
        testClip(
            audioSHA256: sha256(wav),
            totalSamples: totalSamples,
            segments: segments
        )
    }
}

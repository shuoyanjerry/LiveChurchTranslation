import AudioCaptureAPI
import AudioFileAVFoundation
import AudioProcessingCore
import Foundation
import VADAPI

enum ScriptureQualificationContentLoader {
    static func reference(at url: URL) throws -> String {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            throw ScriptureModelQualificationError.invalidReference
        }
        guard data.count <= maximumReferenceBytes,
            let value = String(data: data, encoding: .utf8)
        else { throw ScriptureModelQualificationError.invalidReference }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maximumReferenceCharacters,
            !trimmed.contains("\0")
        else { throw ScriptureModelQualificationError.invalidReference }
        return trimmed
    }

    static func speechSegment(at url: URL) async throws -> SpeechSegment {
        let capture = FileAudioCaptureProvider(url: url)
        let processor = try MonoResamplingAudioProcessor()
        do {
            let stream = try await capture.startCapture(
                request: AudioCaptureRequest(bufferDuration: .milliseconds(250))
            )
            var samples: [Float] = []
            for try await frame in stream {
                try Task.checkCancellation()
                let processed = try await processor.process(frame)
                guard samples.count <= maximumSamples - processed.samples.count else {
                    throw ScriptureModelQualificationError.invalidAudio
                }
                samples.append(contentsOf: processed.samples)
            }
            await capture.stopCapture()
            guard !samples.isEmpty else { throw ScriptureModelQualificationError.invalidAudio }
            return SpeechSegment(
                sequenceNumber: 0,
                samples: samples,
                sampleRate: sampleRate,
                startedAt: .zero,
                endedAt: .seconds(Double(samples.count) / sampleRate),
                endReason: .endOfStream
            )
        } catch {
            await capture.stopCapture()
            throw error
        }
    }

    private static let sampleRate = 16_000.0
    private static let maximumSamples = 16_000 * 300
    private static let maximumReferenceBytes = 400_000
    private static let maximumReferenceCharacters = 100_000
}

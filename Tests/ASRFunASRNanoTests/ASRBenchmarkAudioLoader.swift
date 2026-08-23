import AVFoundation
import Foundation
import VADAPI

enum ASRBenchmarkAudioLoader {
    static func load(
        _ fixture: ASRBenchmarkFixture,
        projectRoot: URL
    ) throws -> SpeechSegment {
        let fileURL = URL(fileURLWithPath: fixture.path, relativeTo: projectRoot).standardizedFileURL
        let file = try AVAudioFile(forReading: fileURL)
        let format = file.processingFormat
        guard format.sampleRate == 16_000, format.channelCount == 1 else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }
        let startFrame = AVAudioFramePosition(fixture.startSeconds * format.sampleRate)
        let requestedFrames = AVAudioFrameCount(fixture.durationSeconds * format.sampleRate)
        guard startFrame >= 0, startFrame < file.length, requestedFrames > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let available = AVAudioFrameCount(min(Int64(requestedFrames), file.length - startFrame))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: available) else {
            throw CocoaError(.fileReadUnknown)
        }
        file.framePosition = startFrame
        try file.read(into: buffer, frameCount: available)
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        let duration = Double(samples.count) / format.sampleRate
        return SpeechSegment(
            sequenceNumber: 0,
            samples: samples,
            sampleRate: format.sampleRate,
            startedAt: .zero,
            endedAt: .seconds(duration),
            endReason: .trailingSilence
        )
    }

    static func silence(seconds: Double = 3) -> SpeechSegment {
        SpeechSegment(
            sequenceNumber: 0,
            samples: Array(repeating: 0, count: Int(seconds * 16_000)),
            sampleRate: 16_000,
            startedAt: .zero,
            endedAt: .seconds(seconds),
            endReason: .trailingSilence
        )
    }
}

import AVFoundation
import AudioProcessingAPI
import Foundation
import Testing
import VADAPI
import VADCore
import VADWebRTC

@Suite("Local real-sermon VAD qualification")
struct RealSermonReplayTests {
    @Test(
        "replays every supplied 16 kHz mono sermon",
        .enabled(
            if: ProcessInfo.processInfo.environment["SERMON_WAV_DIR"] != nil,
            "Requires SERMON_WAV_DIR; copyrighted media stays outside the repository."
        )
    )
    func replaySuppliedCorpus() async throws {
        guard let directory = ProcessInfo.processInfo.environment["SERMON_WAV_DIR"] else { return }
        let urls = try wavURLs(in: URL(fileURLWithPath: directory))
        #expect(urls.count >= 2)

        var totalSegments = 0
        var totalShortSegments = 0
        for url in urls {
            let result = try await replay(url)
            totalSegments += result.durations.count
            totalShortSegments += result.durations.count { $0 < 2 }
            print("VAD_REAL_\(url.lastPathComponent)=\(result.summary)")
            #expect(result.maximumDuration <= 16.52)
        }
        #expect(totalSegments > 0)
        print("VAD_REAL_TOTAL=segments:\(totalSegments),under2s:\(totalShortSegments)")
    }

    private func replay(_ url: URL) async throws -> ReplayResult {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        #expect(format.sampleRate == 16_000)
        #expect(format.channelCount == 1)
        let detector = try CalibratedVoiceActivityDetector(
            classifier: try WebRTCVoiceActivityClassifier()
        )
        var durations: [Double] = []
        var reasons: [String: Int] = [:]
        var processedSamples: Int64 = 0
        let capacity: AVAudioFrameCount = 16_000
        while file.framePosition < file.length {
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity))
            try file.read(into: buffer)
            let samples = try samples(from: buffer)
            for start in stride(from: 0, to: samples.count, by: 320) {
                let end = min(start + 320, samples.count)
                guard end - start == 320 else { continue }
                let timestamp = Duration.milliseconds(processedSamples / 16)
                let frame = ProcessedAudioFrame(
                    samples: Array(samples[start..<end]),
                    sampleRate: 16_000,
                    timestamp: timestamp
                )
                let events = try await detector.process(frame)
                durations += events.segmentDurations
                accumulate(events.segmentReasons, into: &reasons)
                processedSamples += 320
            }
        }
        let finalEvents = await detector.flush()
        durations += finalEvents.segmentDurations
        accumulate(finalEvents.segmentReasons, into: &reasons)
        return ReplayResult(durations: durations, reasons: reasons)
    }

    private func accumulate(
        _ values: [String],
        into counts: inout [String: Int]
    ) {
        for value in values {
            counts[value, default: 0] += 1
        }
    }

    private func samples(from buffer: AVAudioPCMBuffer) throws -> [Float] {
        let channels = try #require(buffer.floatChannelData)
        return Array(UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength)))
    }

    private func wavURLs(in directory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension.lowercased() == "wav" }.sorted {
            $0.lastPathComponent < $1.lastPathComponent
        }
    }
}

private struct ReplayResult {
    let durations: [Double]
    let reasons: [String: Int]

    var maximumDuration: Double { durations.max() ?? 0 }
    var summary: String {
        let short = durations.count { $0 < 2 }
        let reasonSummary = reasons.keys.sorted().map { "\($0):\(reasons[$0] ?? 0)" }
            .joined(separator: ",")
        return "segments:\(durations.count),under2s:\(short),max:\(maximumDuration),\(reasonSummary)"
    }
}

extension Array where Element == VoiceActivityEvent {
    fileprivate var segmentDurations: [Double] {
        compactMap { event in
            guard case .speechEnded(let segment) = event else { return nil }
            return segment.duration.secondsValue
        }
    }

    fileprivate var segmentReasons: [String] {
        compactMap { event in
            guard case .speechEnded(let segment) = event else { return nil }
            return switch segment.endReason {
            case .trailingSilence: "trailing"
            case .softSilence: "soft"
            case .maximumBoundary: "maximumBoundary"
            case .maximumDuration: "maximumDuration"
            case .endOfStream: "endOfStream"
            }
        }
    }
}

extension Duration {
    fileprivate var secondsValue: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}

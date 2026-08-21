import AudioProcessingAPI
import VADAPI

enum VADTestSupport {
    static let sampleRate = 16_000.0

    static func frame(
        amplitude: Float,
        milliseconds: Int,
        timestamp: Duration
    ) -> ProcessedAudioFrame {
        ProcessedAudioFrame(
            samples: Array(
                repeating: amplitude,
                count: sampleCount(milliseconds: milliseconds)
            ),
            sampleRate: sampleRate,
            timestamp: timestamp
        )
    }

    static func sampleCount(milliseconds: Int) -> Int {
        Int(sampleRate * Double(milliseconds) / 1_000)
    }

    static func startedEvents(
        in events: [VoiceActivityEvent]
    ) -> [(sequenceNumber: UInt64, at: Duration)] {
        events.compactMap { event in
            guard case .speechStarted(let sequenceNumber, let timestamp) = event else {
                return nil
            }
            return (sequenceNumber, timestamp)
        }
    }

    static func endedSegments(
        in events: [VoiceActivityEvent]
    ) -> [SpeechSegment] {
        events.compactMap { event in
            guard case .speechEnded(let segment) = event else { return nil }
            return segment
        }
    }
}

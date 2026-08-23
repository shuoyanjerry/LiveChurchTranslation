import CryptoKit
import Foundation
import VADAPI

struct V3SelectedVADVoiceSignature: Codable, Equatable {
    let kind: String
    let sequenceNumber: UInt64
    let startedAtSample: Int64
    let endedAtSample: Int64?
    let sampleCount: Int?
    let pcmSHA256: String?
    let reason: String?

    static func make(_ event: VoiceActivityEvent) -> Self {
        switch event {
        case .speechStarted(let sequenceNumber, let timestamp):
            Self(
                kind: "speechStarted",
                sequenceNumber: sequenceNumber,
                startedAtSample: sampleIndex(timestamp),
                endedAtSample: nil,
                sampleCount: nil,
                pcmSHA256: nil,
                reason: nil
            )
        case .speechEnded(let segment):
            Self(
                kind: "speechEnded",
                sequenceNumber: segment.sequenceNumber,
                startedAtSample: sampleIndex(segment.startedAt),
                endedAtSample: sampleIndex(segment.endedAt),
                sampleCount: segment.samples.count,
                pcmSHA256: pcmDigest(segment.samples),
                reason: segment.endReason.v3Name
            )
        }
    }

    private static func sampleIndex(_ duration: Duration) -> Int64 {
        let value = duration.components
        return value.seconds * 16_000 + value.attoseconds / 62_500_000_000_000
    }

    private static func pcmDigest(_ samples: [Float]) -> String {
        var hasher = SHA256()
        for sample in samples {
            var bits = sample.bitPattern.littleEndian
            withUnsafeBytes(of: &bits) { hasher.update(bufferPointer: $0) }
        }
        return V3SelectedVADHashing.hex(hasher.finalize())
    }
}

extension SpeechSegmentEndReason {
    var v3Name: String {
        switch self {
        case .trailingSilence: "trailingSilence"
        case .softSilence: "softSilence"
        case .maximumBoundary: "maximumBoundary"
        case .maximumDuration: "maximumDuration"
        case .endOfStream: "endOfStream"
        }
    }
}

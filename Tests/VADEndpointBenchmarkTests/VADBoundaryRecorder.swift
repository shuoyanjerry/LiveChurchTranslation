import CryptoKit
import Foundation
import VADAPI

struct VADBoundaryRecorder {
    let sampleRate: Double

    func append(
        _ events: [VoiceActivityEvent],
        emittedAtSample: Int,
        syntheticPaddingSamples: Int,
        to boundaries: inout [VADBoundaryRecord]
    ) {
        let emittedAt = Double(emittedAtSample) / sampleRate
        for event in events {
            guard case .speechEnded(let segment) = event else { continue }
            let endedAt = segment.endedAt.secondsValue
            let signedOffset = emittedAt - endedAt
            let startSample = Int((segment.startedAt.secondsValue * sampleRate).rounded())
            let validSampleCount = segment.samples.count
            let lag =
                segment.endReason == .endOfStream || signedOffset < 0
                ? nil
                : signedOffset
            boundaries.append(
                VADBoundaryRecord(
                    sequenceNumber: segment.sequenceNumber,
                    startSample: startSample,
                    endSample: startSample + validSampleCount,
                    validSampleCount: validSampleCount,
                    pcmSHA256: Self.pcmDigest(segment.samples),
                    startedAtSeconds: segment.startedAt.secondsValue,
                    endedAtSeconds: endedAt,
                    durationSeconds: segment.duration.secondsValue,
                    reason: segment.endReason.benchmarkName,
                    signedEmissionOffsetSeconds: signedOffset,
                    emissionLagAfterRetainedAudioSeconds: lag,
                    syntheticPaddingSamplesAtEmission: syntheticPaddingSamples
                )
            )
        }
    }

    private static func pcmDigest(_ samples: [Float]) -> String {
        var hasher = SHA256()
        for sample in samples {
            var bits = sample.bitPattern.littleEndian
            withUnsafeBytes(of: &bits) { hasher.update(bufferPointer: $0) }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

extension Duration {
    var secondsValue: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}

extension SpeechSegmentEndReason {
    fileprivate var benchmarkName: String {
        switch self {
        case .trailingSilence: "trailingSilence"
        case .softSilence: "softSilence"
        case .maximumBoundary: "maximumBoundary"
        case .maximumDuration: "maximumDuration"
        case .endOfStream: "endOfStream"
        }
    }
}

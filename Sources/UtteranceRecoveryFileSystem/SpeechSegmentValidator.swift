import UtteranceRecoveryAPI
import VADAPI

struct SpeechSegmentValidator {
    let limits: UtteranceRecoveryLimits

    func validate(_ segment: SpeechSegment) throws -> UInt32 {
        guard !segment.samples.isEmpty else { throw UtteranceRecoveryError.emptySamples }
        guard segment.samples.count <= limits.maximumSampleCount else {
            throw UtteranceRecoveryError.sampleCountExceeded(
                actual: segment.samples.count,
                maximum: limits.maximumSampleCount
            )
        }
        let wavBytes = WAVFormat.headerByteCount + segment.samples.count * WAVFormat.bytesPerSample
        guard wavBytes <= limits.maximumWAVFileBytes else {
            throw UtteranceRecoveryError.audioFileSizeExceeded(
                actual: wavBytes,
                maximum: limits.maximumWAVFileBytes
            )
        }
        let roundedRate = segment.sampleRate.rounded()
        guard
            segment.sampleRate.isFinite,
            roundedRate == segment.sampleRate,
            roundedRate >= Double(limits.minimumSampleRate),
            roundedRate <= Double(limits.maximumSampleRate),
            let sampleRate = UInt32(exactly: roundedRate)
        else {
            throw UtteranceRecoveryError.invalidSampleRate(segment.sampleRate)
        }
        guard segment.startedAt >= .zero, segment.endedAt >= segment.startedAt else {
            throw UtteranceRecoveryError.invalidTiming
        }
        if let index = segment.samples.firstIndex(where: { !$0.isFinite }) {
            throw UtteranceRecoveryError.nonFiniteSample(index: index)
        }
        return sampleRate
    }
}

import Foundation

public enum RecordingStoreError: Error, Equatable, LocalizedError, Sendable {
    case invalidSampleRate(Double)
    case invalidChannelCount(Int)
    case unsupportedFormat(RecordingFormat)
    case emptyFrame
    case unalignedSamples(sampleCount: Int, channelCount: Int)
    case nonFiniteSample(index: Int)
    case sampleOutOfRange(index: Int)
    case formatChanged(expected: RecordingFormat, actual: RecordingFormat)
    case sessionAlreadyActive(UUID)
    case sessionNotActive(UUID)
    case recordingAlreadyExists(UUID)
    case interruptedRecordingExists(UUID)
    case noAudio(UUID)
    case dataLimitExceeded(attemptedBytes: UInt64, maximumBytes: UInt64)
    case malformedPartialRecording(sessionID: UUID, reason: String)
    case invalidConfiguration(String)
    case fileSystem(operation: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .invalidSampleRate(let value):
            "The recording sample rate is invalid: \(value)."
        case .invalidChannelCount(let value):
            "The recording channel count is invalid: \(value)."
        case .unsupportedFormat(let format):
            "PCM16 CAF cannot represent \(format.sampleRate) Hz with \(format.channelCount) channels."
        case .emptyFrame:
            "An empty audio frame cannot be recorded."
        case .unalignedSamples(let count, let channels):
            "The \(count) samples do not contain complete \(channels)-channel frames."
        case .nonFiniteSample(let index):
            "Audio sample \(index) is not finite."
        case .sampleOutOfRange(let index):
            "Audio sample \(index) is outside the normalized range."
        case .formatChanged(let expected, let actual):
            "Recording format changed from \(expected) to \(actual)."
        case .sessionAlreadyActive:
            "The recording session is already active."
        case .sessionNotActive:
            "The recording session is not active."
        case .recordingAlreadyExists:
            "A completed recording already exists for the session."
        case .interruptedRecordingExists:
            "An interrupted recording must be repaired before recording can resume."
        case .noAudio:
            "The recording contains no audio."
        case .dataLimitExceeded(let attempted, let maximum):
            "The recording would use \(attempted) audio bytes; the limit is \(maximum)."
        case .malformedPartialRecording(_, let reason):
            "The interrupted recording is malformed: \(reason)."
        case .invalidConfiguration(let reason):
            "The recording configuration is invalid: \(reason)."
        case .fileSystem(let operation, let reason):
            "Recording storage failed during \(operation): \(reason)"
        }
    }
}

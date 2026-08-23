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
            "录音采样率无效：\(value)。"
        case .invalidChannelCount(let value):
            "录音声道数无效：\(value)。"
        case .unsupportedFormat(let format):
            "PCM16 CAF 无法保存 \(format.sampleRate) Hz、\(format.channelCount) 声道的音频。"
        case .emptyFrame:
            "无法写入空音频帧。"
        case .unalignedSamples(let count, let channels):
            "\(count) 个样本无法组成完整的 \(channels) 声道音频帧。"
        case .nonFiniteSample(let index):
            "音频样本 \(index) 不是有限数值。"
        case .sampleOutOfRange(let index):
            "音频样本 \(index) 超出标准化范围。"
        case .formatChanged(let expected, let actual):
            "录音格式从 \(expected) 意外变为 \(actual)。"
        case .sessionAlreadyActive:
            "录音会话已经在进行。"
        case .sessionNotActive:
            "录音会话尚未开始。"
        case .recordingAlreadyExists:
            "这场会议已经存在完整录音。"
        case .interruptedRecordingExists:
            "继续录音前必须先修复上次中断的录音。"
        case .noAudio:
            "录音中没有音频内容。"
        case .dataLimitExceeded(let attempted, let maximum):
            "录音将使用 \(attempted) 字节，超过 \(maximum) 字节上限。"
        case .malformedPartialRecording(_, let reason):
            "中断的录音已损坏：\(reason)。"
        case .invalidConfiguration(let reason):
            "录音配置无效：\(reason)。"
        case .fileSystem(let operation, let reason):
            "录音存储在执行 \(operation) 时失败：\(reason)"
        }
    }
}

import Foundation

public struct RecordingFormat: Equatable, Sendable {
    public let sampleRate: UInt32
    public let channelCount: Int

    public init(sampleRate: UInt32, channelCount: Int) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }
}

public struct SessionRecordingMetadata: Equatable, Sendable {
    public let sessionID: UUID
    public let fileURL: URL
    public let format: RecordingFormat
    public let frameCount: UInt64
    public let audioDataByteCount: UInt64
    public let recoveredFromInterruption: Bool

    public init(
        sessionID: UUID,
        fileURL: URL,
        format: RecordingFormat,
        frameCount: UInt64,
        audioDataByteCount: UInt64,
        recoveredFromInterruption: Bool
    ) {
        self.sessionID = sessionID
        self.fileURL = fileURL
        self.format = format
        self.frameCount = frameCount
        self.audioDataByteCount = audioDataByteCount
        self.recoveredFromInterruption = recoveredFromInterruption
    }

    public var durationSeconds: Double {
        Double(frameCount) / Double(format.sampleRate)
    }
}

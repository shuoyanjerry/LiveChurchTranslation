import Foundation
import UtteranceRecoveryAPI
import VADAPI

/// Actor-isolated, crash-safe filesystem implementation of utterance recovery.
public actor FileUtteranceRecoveryStore: UtteranceRecoveryStore {
    let layout: RecoveryLayout
    let limits: UtteranceRecoveryLimits
    let fileManager: FileManager
    let writer: DurableFileWriter
    let now: @Sendable () -> Date

    public init(
        root: URL,
        limits: UtteranceRecoveryLimits = .sermonDefault,
        fileManager: FileManager = .default,
        now: @escaping @Sendable () -> Date = { Date() }
    ) throws {
        try limits.validate()
        layout = RecoveryLayout(root: root)
        self.limits = limits
        self.fileManager = fileManager
        writer = DurableFileWriter(fileManager: fileManager)
        self.now = now
    }

    public func stage(
        _ segment: SpeechSegment,
        for sessionID: UUID
    ) async throws -> PendingUtteranceRecord {
        do {
            let sampleRate = try SpeechSegmentValidator(limits: limits).validate(segment)
            let id = PendingUtteranceID(
                sessionID: sessionID,
                segmentID: segment.id,
                sequenceNumber: segment.sequenceNumber
            )
            let destination = layout.recordDirectory(id)
            guard !fileManager.fileExists(atPath: destination.path) else {
                throw UtteranceRecoveryError.duplicate(id)
            }
            let stagedAt = now()
            try writeRecord(
                segment: segment,
                sampleRate: sampleRate,
                sessionID: sessionID,
                stagedAt: stagedAt,
                destination: destination
            )
            return PendingUtteranceRecord(id: id, segment: segment, stagedAt: stagedAt)
        } catch let error as UtteranceRecoveryError {
            throw error
        } catch {
            throw fileSystemError("stage", error)
        }
    }

    private func writeRecord(
        segment: SpeechSegment,
        sampleRate: UInt32,
        sessionID: UUID,
        stagedAt: Date,
        destination: URL
    ) throws {
        try prepareSessionDirectory(sessionID)
        let pending = layout.pendingDirectory(sessionID)
        let staging = layout.stagingDirectory(sessionID)
        try writer.createPrivateDirectory(staging)
        defer { try? fileManager.removeItem(at: staging) }
        let wav = WAVCodec.encode(samples: segment.samples, sampleRate: sampleRate)
        let metadata = PendingMetadata(
            sessionID: sessionID,
            segment: segment,
            wavFileBytes: wav.count,
            stagedAt: stagedAt
        )
        try writer.write(wav, to: layout.audioURL(in: staging))
        try writer.write(try encode(metadata), to: layout.metadataURL(in: staging))
        try writer.synchronizeDirectory(staging)
        try fileManager.moveItem(at: staging, to: destination)
        try writer.synchronizeDirectory(pending)
    }

    private func encode(_ metadata: PendingMetadata) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(metadata)
        guard data.count <= limits.maximumMetadataBytes else {
            throw UtteranceRecoveryError.invalidConfiguration("maximumMetadataBytes")
        }
        return data
    }

    func fileSystemError(_ operation: String, _ error: Error) -> UtteranceRecoveryError {
        if let recoveryError = error as? UtteranceRecoveryError { return recoveryError }
        return .fileSystem(operation: operation, reason: error.localizedDescription)
    }
}

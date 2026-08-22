import Foundation
import UtteranceRecoveryAPI

struct RecoveryScanner {
    let layout: RecoveryLayout
    let reader: PendingRecordReader
    let writer: DurableFileWriter
    let fileManager: FileManager
    let limits: UtteranceRecoveryLimits
    let now: @Sendable () -> Date

    func scan(sessionID: UUID) throws -> UtteranceRecoveryBatch {
        let pendingDirectory = layout.pendingDirectory(sessionID)
        try writer.createPrivateDirectory(pendingDirectory)
        let urls = try BoundedDirectoryReader(fileManager: fileManager).sessionEntries(
            at: pendingDirectory,
            sessionID: sessionID,
            maximum: limits.maximumEntriesPerSession
        )
        var records: [PendingUtteranceRecord] = []
        var quarantined: [QuarantinedUtterance] = []
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            try process(
                url,
                sessionID: sessionID,
                records: &records,
                quarantined: &quarantined
            )
        }
        try writer.synchronizeDirectory(pendingDirectory)
        records.sort { lhs, rhs in
            if lhs.id.sequenceNumber == rhs.id.sequenceNumber {
                return lhs.id.segmentID.uuidString < rhs.id.segmentID.uuidString
            }
            return lhs.id.sequenceNumber < rhs.id.sequenceNumber
        }
        return UtteranceRecoveryBatch(pending: records, quarantined: quarantined)
    }

    private func process(
        _ url: URL,
        sessionID: UUID,
        records: inout [PendingUtteranceRecord],
        quarantined: inout [QuarantinedUtterance]
    ) throws {
        if url.lastPathComponent.hasPrefix(".completed-") {
            try fileManager.removeItem(at: url)
            return
        }
        do {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard
                url.pathExtension == "utterance",
                values.isDirectory == true,
                values.isSymbolicLink != true
            else {
                let reason: UtteranceQuarantineReason =
                    url.lastPathComponent.hasPrefix(".staging-")
                    ? .incompleteWrite : .orphanedArtifact
                throw RecordReadFailure(reason: reason)
            }
            records.append(try reader.read(url, for: sessionID))
        } catch let failure as RecordReadFailure {
            quarantined.append(try quarantine(url, reason: failure.reason, sessionID: sessionID))
        } catch {
            quarantined.append(try quarantine(url, reason: .orphanedArtifact, sessionID: sessionID))
        }
    }

    private func quarantine(
        _ url: URL,
        reason: UtteranceQuarantineReason,
        sessionID: UUID
    ) throws -> QuarantinedUtterance {
        let directory = layout.quarantineDirectory(sessionID)
        try writer.createPrivateDirectory(directory)
        let destination = directory.appending(path: UUID().uuidString.lowercased())
        try fileManager.moveItem(at: url, to: destination)
        try writer.synchronizeDirectory(directory)
        return QuarantinedUtterance(
            sessionID: sessionID,
            originalName: url.lastPathComponent,
            reason: reason,
            quarantinedAt: now()
        )
    }
}

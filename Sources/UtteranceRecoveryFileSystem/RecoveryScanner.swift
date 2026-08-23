import Foundation
import UtteranceRecoveryAPI

struct RecoverySessionIndex: Sendable {
    let records: [PendingRecordDescriptor]
    let quarantined: [QuarantinedUtterance]
}

enum RecoveryRecordLoad: Sendable {
    case pending(PendingUtteranceRecord)
    case quarantined(QuarantinedUtterance)
}

struct RecoveryScanner {
    let layout: RecoveryLayout
    let reader: PendingRecordReader
    let writer: DurableFileWriter
    let fileManager: FileManager
    let limits: UtteranceRecoveryLimits
    let now: @Sendable () -> Date

    func scan(sessionID: UUID) throws -> UtteranceRecoveryBatch {
        let index = try index(sessionID: sessionID)
        var records: [PendingUtteranceRecord] = []
        var quarantined = index.quarantined
        for descriptor in index.records {
            switch try load(descriptor, sessionID: sessionID) {
            case .pending(let record): records.append(record)
            case .quarantined(let artifact): quarantined.append(artifact)
            }
        }
        return UtteranceRecoveryBatch(pending: records, quarantined: quarantined)
    }

    func index(sessionID: UUID) throws -> RecoverySessionIndex {
        let pendingDirectory = layout.pendingDirectory(sessionID)
        try writer.createPrivateDirectory(pendingDirectory)
        let urls = try BoundedDirectoryReader(fileManager: fileManager).sessionEntries(
            at: pendingDirectory,
            sessionID: sessionID,
            maximum: limits.maximumEntriesPerSession
        )
        var records: [PendingRecordDescriptor] = []
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
        records.sort(by: Self.descriptorsAreOrdered)
        return RecoverySessionIndex(records: records, quarantined: quarantined)
    }

    func load(
        _ descriptor: PendingRecordDescriptor,
        sessionID: UUID
    ) throws -> RecoveryRecordLoad {
        do {
            return .pending(try reader.read(descriptor))
        } catch let failure as RecordReadFailure {
            return .quarantined(
                try quarantine(
                    descriptor.directory,
                    reason: failure.reason,
                    sessionID: sessionID
                )
            )
        } catch {
            return .quarantined(
                try quarantine(
                    descriptor.directory,
                    reason: .orphanedArtifact,
                    sessionID: sessionID
                )
            )
        }
    }

    private func process(
        _ url: URL,
        sessionID: UUID,
        records: inout [PendingRecordDescriptor],
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
            records.append(try reader.inspect(url, for: sessionID))
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
        try writer.synchronizeDirectory(layout.pendingDirectory(sessionID))
        return QuarantinedUtterance(
            sessionID: sessionID,
            originalName: url.lastPathComponent,
            reason: reason,
            quarantinedAt: now()
        )
    }

    private static func descriptorsAreOrdered(
        _ lhs: PendingRecordDescriptor,
        _ rhs: PendingRecordDescriptor
    ) -> Bool {
        if lhs.id.sequenceNumber != rhs.id.sequenceNumber {
            return lhs.id.sequenceNumber < rhs.id.sequenceNumber
        }
        return lhs.id.segmentID.uuidString < rhs.id.segmentID.uuidString
    }
}

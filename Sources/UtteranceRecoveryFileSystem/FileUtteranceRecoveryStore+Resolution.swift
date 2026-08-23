import Foundation
import UtteranceRecoveryAPI

extension FileUtteranceRecoveryStore {
    public func resolve(
        _ id: PendingUtteranceID,
        as resolution: UtteranceRecoveryResolution
    ) async throws {
        switch resolution {
        case .completed, .ignored:
            try removeResolvedRecord(id)
        case .terminallyRejected(let receipts):
            try retainTerminalRejection(id, receipts: receipts)
        }
    }

    private func removeResolvedRecord(_ id: PendingUtteranceID) throws {
        let record = layout.recordDirectory(id)
        let tombstone = layout.completionDirectory(id)
        do {
            if fileManager.fileExists(atPath: record.path) {
                try requireSafeRecordDirectory(record, id: id)
                try fileManager.moveItem(at: record, to: tombstone)
            } else if !fileManager.fileExists(atPath: tombstone.path) {
                throw UtteranceRecoveryError.recordNotFound(id)
            }
            try writer.synchronizeDirectory(layout.pendingDirectory(id.sessionID))
            try? fileManager.removeItem(at: tombstone)
            try? writer.synchronizeDirectory(layout.pendingDirectory(id.sessionID))
            try? cleanupActiveSessionIfEmpty(id.sessionID)
        } catch {
            throw fileSystemError("markCompleted", error)
        }
    }

    private func retainTerminalRejection(
        _ id: PendingUtteranceID,
        receipts: [UtteranceRejectionReceipt]
    ) throws {
        do {
            try validate(receipts)
            let record = layout.recordDirectory(id)
            let destination = layout.rejectedRecordDirectory(id)
            if fileManager.fileExists(atPath: destination.path) {
                try validatePreviouslyRejected(id, receipts: receipts, pendingRecord: record)
                discardRejectedAudioBestEffort(in: destination)
                try synchronizeTerminalResolution(id)
                try? cleanupActiveSessionIfEmpty(id.sessionID)
                return
            }
            guard fileManager.fileExists(atPath: record.path) else {
                throw UtteranceRecoveryError.recordNotFound(id)
            }
            try requireSafeRecordDirectory(record, id: id)
            try moveToRejected(id, receipts: receipts, record: record, destination: destination)
        } catch {
            throw fileSystemError("resolveTerminalRejection", error)
        }
    }

    private func moveToRejected(
        _ id: PendingUtteranceID,
        receipts: [UtteranceRejectionReceipt],
        record: URL,
        destination: URL
    ) throws {
        let rejected = layout.rejectedDirectory(id.sessionID)
        try writer.createPrivateDirectory(layout.resolvedRootDirectory)
        try writer.createPrivateDirectory(rejected)
        try persist(
            TerminalUtteranceRejectionRecord(id: id, resolvedAt: now(), receipts: receipts),
            in: record
        )
        try fileManager.moveItem(at: record, to: destination)
        try writer.synchronizeDirectory(layout.pendingDirectory(id.sessionID))
        try writer.synchronizeDirectory(rejected)
        try writer.synchronizeDirectory(layout.resolvedRootDirectory)
        discardRejectedAudioBestEffort(in: destination)
        try? cleanupActiveSessionIfEmpty(id.sessionID)
    }

    private func requireSafeRecordDirectory(
        _ record: URL,
        id: PendingUtteranceID
    ) throws {
        let values = try record.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true,
            record.lastPathComponent == layout.recordName(id)
        else {
            throw UtteranceRecoveryError.duplicate(id)
        }
    }

    private func synchronizeTerminalResolution(_ id: PendingUtteranceID) throws {
        let pending = layout.pendingDirectory(id.sessionID)
        let session = layout.sessionDirectory(id.sessionID)
        if fileManager.fileExists(atPath: pending.path) {
            try synchronizeResolutionDirectory(pending, expectedName: "pending")
        } else if fileManager.fileExists(atPath: session.path) {
            try synchronizeResolutionDirectory(
                session,
                expectedName: id.sessionID.uuidString.lowercased()
            )
        }
        try writer.synchronizeDirectory(layout.rejectedDirectory(id.sessionID))
        try writer.synchronizeDirectory(layout.resolvedRootDirectory)
        try writer.synchronizeDirectory(layout.root)
    }

    private func synchronizeResolutionDirectory(
        _ directory: URL,
        expectedName: String
    ) throws {
        let values = try directory.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard values.isDirectory == true, values.isSymbolicLink != true,
            directory.lastPathComponent == expectedName
        else {
            throw UtteranceRecoveryError.invalidConfiguration(
                "terminalResolutionSourceDirectory"
            )
        }
        try writer.synchronizeDirectory(directory)
    }

    private func validatePreviouslyRejected(
        _ id: PendingUtteranceID,
        receipts: [UtteranceRejectionReceipt],
        pendingRecord: URL
    ) throws {
        guard !fileManager.fileExists(atPath: pendingRecord.path) else {
            throw UtteranceRecoveryError.duplicate(id)
        }
        let destination = layout.rejectedRecordDirectory(id)
        let values = try destination.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw UtteranceRecoveryError.duplicate(id)
        }
        let stored = try decodeRejection(at: layout.rejectionReceiptURL(in: destination))
        guard stored.id == id, stored.receipts == receipts else {
            throw UtteranceRecoveryError.duplicate(id)
        }
    }

    func decodeRejection(at url: URL) throws -> TerminalUtteranceRejectionRecord {
        let values = try url.resourceValues(
            forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]
        )
        guard
            values.isRegularFile == true,
            values.isSymbolicLink != true,
            let size = values.fileSize,
            size >= 0,
            size <= limits.maximumMetadataBytes
        else {
            throw UtteranceRecoveryError.invalidConfiguration("terminalRejectionReceipt")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(
            TerminalUtteranceRejectionRecord.self,
            from: Data(contentsOf: url, options: [.mappedIfSafe])
        )
    }

    private func discardRejectedAudioBestEffort(in record: URL) {
        try? fileManager.removeItem(at: layout.audioURL(in: record))
        try? writer.synchronizeDirectory(record)
    }
}

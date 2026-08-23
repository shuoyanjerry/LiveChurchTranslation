import Foundation
import UtteranceRecoveryAPI

extension FileUtteranceRecoveryStore {
    public func summary(
        for sessionID: UUID
    ) async throws -> UtteranceRecoverySessionSummary {
        do {
            let active = layout.sessionDirectory(sessionID)
            let resolved = layout.rejectedDirectory(sessionID)
            let hasActive = fileManager.fileExists(atPath: active.path)
            let hasResolved = fileManager.fileExists(atPath: resolved.path)
            guard hasActive || hasResolved else { return .empty }

            var pendingCount = 0
            var quarantineCount = 0
            if hasActive {
                try requireSafeSessionDirectory(active, sessionID: sessionID)
                let index = try sessionScanner().index(sessionID: sessionID)
                pendingCount = index.records.count
                quarantineCount = try artifactCount(
                    at: layout.quarantineDirectory(sessionID),
                    sessionID: sessionID
                )
            }
            let rejections = try rejectionReceipts(
                at: resolved,
                sessionID: sessionID
            )
            return UtteranceRecoverySessionSummary(
                pendingRecordCount: pendingCount,
                rejections: rejections,
                quarantinedArtifactCount: quarantineCount
            )
        } catch {
            throw fileSystemError("sessionSummary", error)
        }
    }

    public func deleteArtifacts(for sessionID: UUID) async throws {
        do {
            try deleteSafeDirectory(
                layout.sessionDirectory(sessionID),
                sessionID: sessionID
            )
            try deleteSafeDirectory(
                layout.rejectedDirectory(sessionID),
                sessionID: sessionID
            )
            if fileManager.fileExists(atPath: layout.root.path) {
                try writer.synchronizeDirectory(layout.root)
            }
            if fileManager.fileExists(atPath: layout.resolvedRootDirectory.path) {
                try writer.synchronizeDirectory(layout.resolvedRootDirectory)
            }
        } catch {
            throw fileSystemError("deleteSessionArtifacts", error)
        }
    }

    private func rejectionReceipts(
        at directory: URL,
        sessionID: UUID
    ) throws -> [UtteranceRejectionReceipt] {
        guard fileManager.fileExists(atPath: directory.path) else { return [] }
        try requireSafeSessionDirectory(directory, sessionID: sessionID)
        let entries = try BoundedDirectoryReader(fileManager: fileManager).sessionEntries(
            at: directory,
            sessionID: sessionID,
            maximum: limits.maximumEntriesPerSession
        )
        var receipts: [UtteranceRejectionReceipt] = []
        for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let values = try entry.resourceValues(
                forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
            )
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                throw UtteranceRecoveryError.invalidConfiguration("terminalRejectionDirectory")
            }
            let stored = try decodeRejection(at: layout.rejectionReceiptURL(in: entry))
            guard stored.id.sessionID == sessionID,
                entry.lastPathComponent == layout.recordName(stored.id)
            else {
                throw UtteranceRecoveryError.duplicate(stored.id)
            }
            try validate(stored.receipts)
            receipts.append(contentsOf: stored.receipts)
            guard receipts.count <= limits.maximumTotalRecoveryCount else {
                throw UtteranceRecoveryError.totalRecoveryCountExceeded(
                    maximum: limits.maximumTotalRecoveryCount
                )
            }
        }
        return Array(Set(receipts)).sorted(by: Self.receiptOrder)
    }

    private func artifactCount(at directory: URL, sessionID: UUID) throws -> Int {
        guard fileManager.fileExists(atPath: directory.path) else { return 0 }
        let values = try directory.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard values.isDirectory == true, values.isSymbolicLink != true else {
            throw UtteranceRecoveryError.invalidConfiguration("quarantineDirectory")
        }
        return try BoundedDirectoryReader(fileManager: fileManager).sessionEntries(
            at: directory,
            sessionID: sessionID,
            maximum: limits.maximumEntriesPerSession
        ).count
    }

    private func requireSafeSessionDirectory(_ directory: URL, sessionID: UUID) throws {
        let values = try directory.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard values.isDirectory == true, values.isSymbolicLink != true,
            directory.lastPathComponent == sessionID.uuidString.lowercased()
        else {
            throw UtteranceRecoveryError.invalidConfiguration("sessionDirectory")
        }
    }

    private func deleteSafeDirectory(_ directory: URL, sessionID: UUID) throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        try requireSafeSessionDirectory(directory, sessionID: sessionID)
        try fileManager.removeItem(at: directory)
    }

    private static func receiptOrder(
        _ left: UtteranceRejectionReceipt,
        _ right: UtteranceRejectionReceipt
    ) -> Bool {
        if left.sentenceID != right.sentenceID {
            return left.sentenceID.uuidString < right.sentenceID.uuidString
        }
        if left.sentenceOrdinal != right.sentenceOrdinal {
            return left.sentenceOrdinal < right.sentenceOrdinal
        }
        if left.stage != right.stage { return left.stage.rawValue < right.stage.rawValue }
        return left.failureCode < right.failureCode
    }
}

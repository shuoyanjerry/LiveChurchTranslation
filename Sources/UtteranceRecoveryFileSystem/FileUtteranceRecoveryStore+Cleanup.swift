import Foundation
import UtteranceRecoveryAPI

extension FileUtteranceRecoveryStore {
    func cleanupActiveSessionIfEmpty(_ sessionID: UUID) throws {
        let session = layout.sessionDirectory(sessionID)
        guard fileManager.fileExists(atPath: session.path) else { return }
        try requireSafeDirectory(
            session,
            expectedName: sessionID.uuidString.lowercased(),
            failureCode: "sessionDirectory"
        )

        let pending = layout.pendingDirectory(sessionID)
        guard
            try directoryIsEmptyIfPresent(
                pending,
                expectedName: "pending",
                failureCode: "pendingDirectory"
            )
        else { return }

        let quarantine = layout.quarantineDirectory(sessionID)
        guard
            try directoryIsEmptyIfPresent(
                quarantine,
                expectedName: "quarantine",
                failureCode: "quarantineDirectory"
            )
        else { return }

        for directory in [pending, quarantine]
        where fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
        guard try fileManager.contentsOfDirectory(atPath: session.path).isEmpty else { return }
        try fileManager.removeItem(at: session)
        if fileManager.fileExists(atPath: layout.root.path) {
            try writer.synchronizeDirectory(layout.root)
        }
    }

    private func directoryIsEmptyIfPresent(
        _ directory: URL,
        expectedName: String,
        failureCode: String
    ) throws -> Bool {
        guard fileManager.fileExists(atPath: directory.path) else { return true }
        try requireSafeDirectory(
            directory,
            expectedName: expectedName,
            failureCode: failureCode
        )
        return try fileManager.contentsOfDirectory(atPath: directory.path).isEmpty
    }

    private func requireSafeDirectory(
        _ directory: URL,
        expectedName: String,
        failureCode: String
    ) throws {
        let values = try directory.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard values.isDirectory == true, values.isSymbolicLink != true,
            directory.lastPathComponent == expectedName
        else {
            throw UtteranceRecoveryError.invalidConfiguration(failureCode)
        }
    }
}

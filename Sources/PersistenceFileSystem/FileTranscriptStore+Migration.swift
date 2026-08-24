import Foundation
import PersistenceAPI
import TranscriptAPI

extension FileTranscriptStore {
    /// Removes legacy persisted translation text before saved sessions are exposed.
    public func migrateLegacySessionsToSourceOnly() throws {
        guard !successfulMigrationScanCompleted else { return }
        guard fileManager.fileExists(atPath: root.path) else {
            successfulMigrationScanCompleted = true
            return
        }
        do {
            try performFullMigrationScan()
            successfulMigrationScanCompleted = true
        } catch let error as TranscriptStoreError {
            throw error
        } catch {
            throw TranscriptStoreError.fileSystem(error.localizedDescription)
        }
    }

    private func performFullMigrationScan() throws {
        let rootValues = try root.resourceValues(
            forKeys: [.isDirectoryKey, .isSymbolicLinkKey]
        )
        guard rootValues.isDirectory == true, rootValues.isSymbolicLink != true else {
            throw TranscriptMigrationError.unsafeRoot
        }
        let failures = TranscriptMigrationFailureCollector()
        guard let enumerator = migrationEnumerator(failures: failures) else {
            throw TranscriptMigrationError.enumerationFailed
        }
        while let directory = enumerator.nextObject() as? URL {
            do {
                try migrateScannedSession(directory)
            } catch {
                failures.capture(error)
            }
        }
        if let failure = failures.firstFailure { throw failure }
    }

    private func migrationEnumerator(
        failures: TranscriptMigrationFailureCollector
    ) -> FileManager.DirectoryEnumerator? {
        fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants],
            errorHandler: { _, error in
                failures.capture(error)
                return true
            }
        )
    }

    private func migrateScannedSession(_ directory: URL) throws {
        guard let sessionID = UUID(uuidString: directory.lastPathComponent) else { return }
        guard try isSafeSessionDirectory(directory) else {
            throw TranscriptMigrationError.unsafeSessionDirectory(sessionID)
        }
        guard fileManager.fileExists(atPath: manifestURL(sessionID).path) else { return }
        try requireSafeRegularFile(manifestURL(sessionID), sessionID: sessionID)
        let manifest = try recoveryManifest(sessionID: sessionID)
        guard manifest.id == sessionID else {
            throw TranscriptMigrationError.manifestIdentifierMismatch(sessionID)
        }
        guard !manifest.storesSourceOnlyEntries else { return }
        try migrateLegacySessionToSourceOnly(sessionID: sessionID, manifest: manifest)
    }

    func migrateLegacySessionToSourceOnly(sessionID: UUID) throws {
        let directory = sessionDirectory(sessionID)
        guard try isSafeSessionDirectory(directory) else {
            throw TranscriptMigrationError.unsafeSessionDirectory(sessionID)
        }
        try requireSafeRegularFile(manifestURL(sessionID), sessionID: sessionID)
        let manifest = try recoveryManifest(sessionID: sessionID)
        guard manifest.id == sessionID else {
            throw TranscriptMigrationError.manifestIdentifierMismatch(sessionID)
        }
        try requireSafeRegularFile(jsonLinesURL(sessionID), sessionID: sessionID)
        if fileManager.fileExists(atPath: markdownURL(sessionID).path) {
            try requireSafeRegularFile(markdownURL(sessionID), sessionID: sessionID)
        }
        guard !manifest.storesSourceOnlyEntries else { return }
        try migrateLegacySessionToSourceOnly(sessionID: sessionID, manifest: manifest)
    }

    private func migrateLegacySessionToSourceOnly(
        sessionID: UUID,
        manifest: SessionManifest
    ) throws {
        guard !activeSessionIDs.contains(sessionID) else {
            throw TranscriptMigrationError.activeLegacySession(sessionID)
        }
        let directory = sessionDirectory(sessionID)
        guard try isSafeSessionDirectory(directory) else {
            throw TranscriptMigrationError.unsafeSessionDirectory(sessionID)
        }
        try requireSafeRegularFile(jsonLinesURL(sessionID), sessionID: sessionID)
        if fileManager.fileExists(atPath: markdownURL(sessionID).path) {
            try requireSafeRegularFile(markdownURL(sessionID), sessionID: sessionID)
        }

        let entries = try readLegacyOrPartiallyMigratedEntries(sessionID: sessionID)
        let session = TranscriptSession(
            id: manifest.id,
            startedAt: manifest.startedAt,
            endedAt: manifest.endedAt,
            entries: entries,
            title: manifest.title,
            kind: manifest.kind,
            sourceLanguage: manifest.sourceLanguage,
            targetLanguage: manifest.targetLanguage
        )

        // The manifest is the commit marker and is deliberately written last.
        try writeEntries(entries, sessionID: sessionID)
        try writeMarkdown(
            completeMarkdown(for: session, integrity: manifest.integrity),
            sessionID: sessionID
        )
        try writeMigratedManifest(from: manifest, session: session)
        try enforcePrivatePermissions(sessionID: sessionID)
    }

    private func readLegacyOrPartiallyMigratedEntries(
        sessionID: UUID
    ) throws -> [TranscriptEntry] {
        let data = try readBoundedData(
            at: jsonLinesURL(sessionID),
            maximumBytes: recoveryLimits.maximumTranscriptBytes
        )
        return try decodeLegacyOrSourceEntries(data)
    }

    private func writeMigratedManifest(
        from legacy: SessionManifest,
        session: TranscriptSession
    ) throws {
        let migrated = SessionManifest(
            id: session.id,
            startedAt: session.startedAt,
            endedAt: session.endedAt,
            entryCount: session.entries.count,
            title: session.title,
            kind: session.kind,
            sourceLanguage: session.sourceLanguage,
            targetLanguage: session.targetLanguage,
            integrity: legacy.integrity,
            pendingRecordCount: legacy.pendingRecordCount,
            rejections: legacy.rejections,
            quarantinedArtifactCount: legacy.quarantinedArtifactCount,
            hasUnrecoverableFailure: legacy.hasUnrecoverableFailure
        )
        try jsonEncoder.encode(migrated).write(
            to: manifestURL(session.id),
            options: .atomic
        )
        try setPrivateFilePermission(manifestURL(session.id))
    }

}

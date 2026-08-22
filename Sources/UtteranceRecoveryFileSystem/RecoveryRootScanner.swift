import Foundation
import UtteranceRecoveryAPI

struct RecoveryRootScanner {
    let layout: RecoveryLayout
    let limits: UtteranceRecoveryLimits
    let reader: PendingRecordReader
    let writer: DurableFileWriter
    let fileManager: FileManager
    let now: @Sendable () -> Date

    func scan() throws -> UtteranceRecoveryBatch {
        try writer.createPrivateDirectory(layout.root)
        try writer.createPrivateDirectory(layout.rootQuarantineDirectory)
        let urls = try BoundedDirectoryReader(fileManager: fileManager).rootEntries(
            at: layout.root,
            maximum: limits.maximumRootEntryCount
        )
        var accumulator = RecoveryRootAccumulator(limits: limits)
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        where url.lastPathComponent != layout.rootQuarantineDirectory.lastPathComponent {
            try process(url, accumulator: &accumulator)
        }
        return accumulator.result()
    }

    private func process(_ url: URL, accumulator: inout RecoveryRootAccumulator) throws {
        do {
            let sessionID = try sessionID(for: url)
            try accumulator.beginSession(sessionID)
            let batch = try sessionScanner().scan(sessionID: sessionID)
            try accumulator.append(batch)
        } catch is RootArtifactFailure {
            try accumulator.append(try quarantineRootArtifact(url))
        }
    }

    private func sessionID(for url: URL) throws -> UUID {
        let values: URLResourceValues
        do {
            values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        } catch {
            throw RootArtifactFailure()
        }
        guard
            values.isDirectory == true,
            values.isSymbolicLink != true,
            let sessionID = UUID(uuidString: url.lastPathComponent),
            url.lastPathComponent == sessionID.uuidString.lowercased()
        else {
            throw RootArtifactFailure()
        }
        return sessionID
    }

    private func sessionScanner() -> RecoveryScanner {
        RecoveryScanner(
            layout: layout,
            reader: reader,
            writer: writer,
            fileManager: fileManager,
            limits: limits,
            now: now
        )
    }

    private func quarantineRootArtifact(_ url: URL) throws -> QuarantinedUtterance {
        let destination = layout.rootQuarantineDirectory
            .appending(path: UUID().uuidString.lowercased())
        try fileManager.moveItem(at: url, to: destination)
        try writer.synchronizeDirectory(layout.rootQuarantineDirectory)
        try writer.synchronizeDirectory(layout.root)
        return QuarantinedUtterance(
            originalName: url.lastPathComponent,
            reason: .orphanedArtifact,
            quarantinedAt: now()
        )
    }
}

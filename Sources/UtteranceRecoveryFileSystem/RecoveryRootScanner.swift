import Foundation
import UtteranceRecoveryAPI

struct RecoveryRootIndex: Sendable {
    let records: [PendingRecordDescriptor]
    let quarantined: [QuarantinedUtterance]
}

struct RecoveryRootScanner {
    let layout: RecoveryLayout
    let limits: UtteranceRecoveryLimits
    let reader: PendingRecordReader
    let writer: DurableFileWriter
    let fileManager: FileManager
    let now: @Sendable () -> Date

    func scan() throws -> UtteranceRecoveryBatch {
        let index = try index()
        var records: [PendingUtteranceRecord] = []
        var quarantined = index.quarantined
        for descriptor in index.records {
            switch try sessionScanner().load(descriptor, sessionID: descriptor.id.sessionID) {
            case .pending(let record): records.append(record)
            case .quarantined(let artifact): quarantined.append(artifact)
            }
        }
        records.sort(by: RecoveryRootAccumulator.recordsAreOrdered)
        quarantined.sort(by: RecoveryRootAccumulator.quarantineIsOrdered)
        return UtteranceRecoveryBatch(pending: records, quarantined: quarantined)
    }

    func index() throws -> RecoveryRootIndex {
        try writer.createPrivateDirectory(layout.root)
        try writer.createPrivateDirectory(layout.rootQuarantineDirectory)
        let urls = try BoundedDirectoryReader(fileManager: fileManager).rootEntries(
            at: layout.root,
            maximum: limits.maximumRootEntryCount
        )
        let sessionURLs =
            urls
            .filter(isSessionDirectoryCandidate)
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent })
        var accumulator = RecoveryRootIndexAccumulator(limits: limits)
        for url in sessionURLs {
            try process(url, accumulator: &accumulator)
        }
        return accumulator.result()
    }

    private func isSessionDirectoryCandidate(_ url: URL) -> Bool {
        url.lastPathComponent != layout.rootQuarantineDirectory.lastPathComponent
            && url.lastPathComponent != layout.resolvedRootDirectory.lastPathComponent
    }

    private func process(_ url: URL, accumulator: inout RecoveryRootIndexAccumulator) throws {
        do {
            let sessionID = try sessionID(for: url)
            try accumulator.beginSession(sessionID)
            let index = try sessionScanner().index(sessionID: sessionID)
            try accumulator.append(index)
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

private struct RecoveryRootIndexAccumulator {
    private var records: [PendingRecordDescriptor] = []
    private var quarantined: [QuarantinedUtterance] = []
    private var sessionIDs: Set<UUID> = []
    private var artifactCount = 0
    let limits: UtteranceRecoveryLimits

    init(limits: UtteranceRecoveryLimits) {
        self.limits = limits
    }

    mutating func beginSession(_ sessionID: UUID) throws {
        guard sessionIDs.insert(sessionID).inserted else { throw RootArtifactFailure() }
        guard sessionIDs.count <= limits.maximumSessionCount else {
            throw UtteranceRecoveryError.sessionCountExceeded(
                maximum: limits.maximumSessionCount
            )
        }
    }

    mutating func append(_ index: RecoverySessionIndex) throws {
        try reserve(index.records.count + index.quarantined.count)
        records.append(contentsOf: index.records)
        quarantined.append(contentsOf: index.quarantined)
    }

    mutating func append(_ item: QuarantinedUtterance) throws {
        try reserve(1)
        quarantined.append(item)
    }

    func result() -> RecoveryRootIndex {
        RecoveryRootIndex(
            records: sessionReplayOrder(records),
            quarantined: quarantined.sorted(by: RecoveryRootAccumulator.quarantineIsOrdered)
        )
    }

    private mutating func reserve(_ count: Int) throws {
        let (newCount, overflow) = artifactCount.addingReportingOverflow(count)
        guard !overflow, newCount <= limits.maximumTotalRecoveryCount else {
            throw UtteranceRecoveryError.totalRecoveryCountExceeded(
                maximum: limits.maximumTotalRecoveryCount
            )
        }
        artifactCount = newCount
    }

    private func sessionReplayOrder(
        _ descriptors: [PendingRecordDescriptor]
    ) -> [PendingRecordDescriptor] {
        let sessions = Dictionary(grouping: descriptors, by: { $0.id.sessionID })
        let orderedSessions = sessions.keys.sorted {
            let left = sessions[$0]?.map(\.stagedAt).min() ?? .distantPast
            let right = sessions[$1]?.map(\.stagedAt).min() ?? .distantPast
            return left == right ? $0.uuidString < $1.uuidString : left < right
        }
        return orderedSessions.flatMap { sessions[$0] ?? [] }
    }
}

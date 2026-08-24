import Foundation
import UtteranceRecoveryAPI
import VADAPI

actor FakeUtteranceRecoveryStore: UtteranceRecoveryStore {
    private let stageFails: Bool
    private var records: [PendingUtteranceID: PendingUtteranceRecord] = [:]
    private var completed: [PendingUtteranceID] = []
    private var resolutions: [(PendingUtteranceID, UtteranceRecoveryResolution)] = []
    private var requestedPageSizes: [Int] = []
    private var stageAttempts = 0

    init(stageFails: Bool = false) {
        self.stageFails = stageFails
    }

    func stage(
        _ segment: SpeechSegment,
        for sessionID: UUID
    ) throws -> PendingUtteranceRecord {
        try stage(segment, for: sessionID, processingTopology: .segmentEntry)
    }

    func stageLegacySentenceEntries(
        _ segment: SpeechSegment,
        for sessionID: UUID
    ) throws -> PendingUtteranceRecord {
        try stage(segment, for: sessionID, processingTopology: .unversionedV1)
    }

    private func stage(
        _ segment: SpeechSegment,
        for sessionID: UUID,
        processingTopology: UtteranceProcessingTopology
    ) throws -> PendingUtteranceRecord {
        stageAttempts += 1
        if stageFails { throw FakeUtteranceRecoveryError.stageFailed }
        let id = PendingUtteranceID(
            sessionID: sessionID,
            segmentID: segment.id,
            sequenceNumber: segment.sequenceNumber
        )
        let record = PendingUtteranceRecord(
            id: id,
            segment: segment,
            stagedAt: Date(),
            processingTopology: processingTopology
        )
        records[id] = record
        return record
    }

    func recoverPending(for sessionID: UUID) -> UtteranceRecoveryBatch {
        let pending = records.values
            .filter { $0.id.sessionID == sessionID }
            .sorted { $0.id.sequenceNumber < $1.id.sequenceNumber }
        return UtteranceRecoveryBatch(pending: pending, quarantined: [])
    }

    func recoverAllPending() -> UtteranceRecoveryBatch {
        UtteranceRecoveryBatch(pending: orderedRecords(), quarantined: [])
    }

    func recoverAllPendingPages(
        maximumRecordsPerPage: Int
    ) throws -> UtteranceRecoveryPages {
        guard maximumRecordsPerPage > 0 else {
            throw UtteranceRecoveryError.invalidConfiguration("maximumRecordsPerPage")
        }
        requestedPageSizes.append(maximumRecordsPerPage)
        let source = FakeRecoveryPageSource(
            records: orderedRecords(),
            pageSize: maximumRecordsPerPage
        )
        return UtteranceRecoveryPages { await source.next() }
    }

    func summary(for sessionID: UUID) -> UtteranceRecoverySessionSummary {
        let pendingCount = records.values.filter { $0.id.sessionID == sessionID }.count
        let rejections = resolutions.flatMap { id, resolution -> [UtteranceRejectionReceipt] in
            guard id.sessionID == sessionID,
                case .terminallyRejected(let receipts) = resolution
            else { return [] }
            return receipts
        }
        return UtteranceRecoverySessionSummary(
            pendingRecordCount: pendingCount,
            rejections: rejections,
            quarantinedArtifactCount: 0
        )
    }

    func resolve(
        _ id: PendingUtteranceID,
        as resolution: UtteranceRecoveryResolution
    ) throws {
        guard records[id] != nil else {
            if isRepeatedTerminalResolution(id, resolution: resolution) { return }
            throw UtteranceRecoveryError.recordNotFound(id)
        }
        records.removeValue(forKey: id)
        resolutions.append((id, resolution))
        if resolution == .completed || resolution == .ignored {
            completed.append(id)
        }
    }

    func deleteArtifacts(for sessionID: UUID) {
        records = records.filter { $0.key.sessionID != sessionID }
        resolutions.removeAll { $0.0.sessionID == sessionID }
        completed.removeAll { $0.sessionID == sessionID }
    }
}

extension FakeUtteranceRecoveryStore {
    func pendingRecords() -> [PendingUtteranceRecord] { Array(records.values) }
    func completedIDs() -> [PendingUtteranceID] { completed }
    func terminalRejections() -> [(PendingUtteranceID, [UtteranceRejectionReceipt])] {
        resolutions.compactMap { id, resolution in
            guard case .terminallyRejected(let receipts) = resolution else { return nil }
            return (id, receipts)
        }
    }
    func recoveryPageSizes() -> [Int] { requestedPageSizes }
    func stageAttemptCount() -> Int { stageAttempts }

    private func isRepeatedTerminalResolution(
        _ id: PendingUtteranceID,
        resolution: UtteranceRecoveryResolution
    ) -> Bool {
        guard case .terminallyRejected = resolution else { return false }
        return resolutions.contains { resolvedID, storedResolution in
            resolvedID == id && storedResolution == resolution
        }
    }

    private func orderedRecords() -> [PendingUtteranceRecord] {
        let sessions = Dictionary(grouping: records.values, by: { $0.id.sessionID })
        let orderedSessions = sessions.keys.sorted {
            let left = sessions[$0]?.map(\.stagedAt).min() ?? .distantPast
            let right = sessions[$1]?.map(\.stagedAt).min() ?? .distantPast
            return left == right ? $0.uuidString < $1.uuidString : left < right
        }
        return orderedSessions.flatMap { sessionID in
            (sessions[sessionID] ?? []).sorted { $0.id.sequenceNumber < $1.id.sequenceNumber }
        }
    }
}

private actor FakeRecoveryPageSource {
    let records: [PendingUtteranceRecord]
    let pageSize: Int
    var index = 0

    init(records: [PendingUtteranceRecord], pageSize: Int) {
        self.records = records
        self.pageSize = pageSize
    }

    func next() -> UtteranceRecoveryBatch? {
        guard index < records.count else { return nil }
        let end = min(index + pageSize, records.count)
        defer { index = end }
        return UtteranceRecoveryBatch(
            pending: Array(records[index..<end]),
            quarantined: []
        )
    }
}

private enum FakeUtteranceRecoveryError: LocalizedError {
    case stageFailed

    var errorDescription: String? {
        "The fake recovery store could not stage the segment."
    }
}

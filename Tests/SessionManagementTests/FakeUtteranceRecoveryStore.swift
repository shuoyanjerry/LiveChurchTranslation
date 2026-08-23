import Foundation
import UtteranceRecoveryAPI
import VADAPI

actor FakeUtteranceRecoveryStore: UtteranceRecoveryStore {
    private let stageFails: Bool
    private var records: [PendingUtteranceID: PendingUtteranceRecord] = [:]
    private var completed: [PendingUtteranceID] = []
    private var requestedPageSizes: [Int] = []

    init(stageFails: Bool = false) {
        self.stageFails = stageFails
    }

    func stage(
        _ segment: SpeechSegment,
        for sessionID: UUID
    ) throws -> PendingUtteranceRecord {
        if stageFails { throw FakeUtteranceRecoveryError.stageFailed }
        let id = PendingUtteranceID(
            sessionID: sessionID,
            segmentID: segment.id,
            sequenceNumber: segment.sequenceNumber
        )
        let record = PendingUtteranceRecord(id: id, segment: segment, stagedAt: Date())
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

    func markCompleted(_ id: PendingUtteranceID) throws {
        guard records.removeValue(forKey: id) != nil else {
            throw UtteranceRecoveryError.recordNotFound(id)
        }
        completed.append(id)
    }

    func pendingRecords() -> [PendingUtteranceRecord] { Array(records.values) }
    func completedIDs() -> [PendingUtteranceID] { completed }
    func recoveryPageSizes() -> [Int] { requestedPageSizes }

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
        "The fake recovery store could not stage the sentence."
    }
}

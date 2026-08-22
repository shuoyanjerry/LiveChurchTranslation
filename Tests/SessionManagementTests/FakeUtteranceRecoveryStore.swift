import Foundation
import UtteranceRecoveryAPI
import VADAPI

actor FakeUtteranceRecoveryStore: UtteranceRecoveryStore {
    private var records: [PendingUtteranceID: PendingUtteranceRecord] = [:]
    private var completed: [PendingUtteranceID] = []

    func stage(
        _ segment: SpeechSegment,
        for sessionID: UUID
    ) -> PendingUtteranceRecord {
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
        let pending = records.values.sorted {
            if $0.stagedAt == $1.stagedAt {
                return $0.id.sequenceNumber < $1.id.sequenceNumber
            }
            return $0.stagedAt < $1.stagedAt
        }
        return UtteranceRecoveryBatch(pending: pending, quarantined: [])
    }

    func markCompleted(_ id: PendingUtteranceID) throws {
        guard records.removeValue(forKey: id) != nil else {
            throw UtteranceRecoveryError.recordNotFound(id)
        }
        completed.append(id)
    }

    func pendingRecords() -> [PendingUtteranceRecord] { Array(records.values) }
    func completedIDs() -> [PendingUtteranceID] { completed }
}

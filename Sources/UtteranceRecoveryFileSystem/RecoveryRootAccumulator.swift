import Foundation
import UtteranceRecoveryAPI

struct RecoveryRootAccumulator {
    private(set) var records: [PendingUtteranceRecord] = []
    private(set) var quarantined: [QuarantinedUtterance] = []
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

    mutating func append(_ batch: UtteranceRecoveryBatch) throws {
        try reserve(batch.pending.count + batch.quarantined.count)
        records.append(contentsOf: batch.pending)
        quarantined.append(contentsOf: batch.quarantined)
    }

    mutating func append(_ item: QuarantinedUtterance) throws {
        try reserve(1)
        quarantined.append(item)
    }

    func result() -> UtteranceRecoveryBatch {
        let orderedRecords = records.sorted(by: Self.recordsAreOrdered)
        let orderedQuarantine = quarantined.sorted(by: Self.quarantineIsOrdered)
        return UtteranceRecoveryBatch(
            pending: orderedRecords,
            quarantined: orderedQuarantine
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

    static func recordsAreOrdered(
        _ lhs: PendingUtteranceRecord,
        _ rhs: PendingUtteranceRecord
    ) -> Bool {
        if lhs.stagedAt != rhs.stagedAt { return lhs.stagedAt < rhs.stagedAt }
        if lhs.id.sessionID != rhs.id.sessionID {
            return lhs.id.sessionID.uuidString < rhs.id.sessionID.uuidString
        }
        if lhs.id.sequenceNumber != rhs.id.sequenceNumber {
            return lhs.id.sequenceNumber < rhs.id.sequenceNumber
        }
        return lhs.id.segmentID.uuidString < rhs.id.segmentID.uuidString
    }

    static func quarantineIsOrdered(
        _ lhs: QuarantinedUtterance,
        _ rhs: QuarantinedUtterance
    ) -> Bool {
        if lhs.quarantinedAt != rhs.quarantinedAt {
            return lhs.quarantinedAt < rhs.quarantinedAt
        }
        let lhsSession = lhs.sessionID?.uuidString ?? ""
        let rhsSession = rhs.sessionID?.uuidString ?? ""
        if lhsSession != rhsSession { return lhsSession < rhsSession }
        return lhs.originalName < rhs.originalName
    }
}

struct RootArtifactFailure: Error {}

import Foundation

/// Single-pass, demand-driven pages of durable recovery artifacts.
public struct UtteranceRecoveryPages: AsyncSequence, Sendable {
    public typealias Element = UtteranceRecoveryBatch

    public struct AsyncIterator: AsyncIteratorProtocol {
        private let nextPage: @Sendable () async throws -> UtteranceRecoveryBatch?

        init(nextPage: @escaping @Sendable () async throws -> UtteranceRecoveryBatch?) {
            self.nextPage = nextPage
        }

        public mutating func next() async throws -> UtteranceRecoveryBatch? {
            try await nextPage()
        }
    }

    private let nextPage: @Sendable () async throws -> UtteranceRecoveryBatch?

    public init(
        nextPage: @escaping @Sendable () async throws -> UtteranceRecoveryBatch?
    ) {
        self.nextPage = nextPage
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(nextPage: nextPage)
    }
}

actor LegacyRecoveryPageSource {
    private let maximumRecordsPerPage: Int
    private let pending: [PendingUtteranceRecord]
    private let quarantined: [QuarantinedUtterance]
    private var pendingIndex = 0
    private var quarantineIndex = 0

    init(batch: UtteranceRecoveryBatch, maximumRecordsPerPage: Int) {
        self.maximumRecordsPerPage = maximumRecordsPerPage
        pending = Self.sessionReplayOrder(batch.pending)
        quarantined = batch.quarantined
    }

    func next() -> UtteranceRecoveryBatch? {
        guard quarantineIndex < quarantined.count || pendingIndex < pending.count else {
            return nil
        }
        if quarantineIndex < quarantined.count {
            let end = min(quarantineIndex + maximumRecordsPerPage, quarantined.count)
            defer { quarantineIndex = end }
            return UtteranceRecoveryBatch(
                pending: [],
                quarantined: Array(quarantined[quarantineIndex..<end])
            )
        }
        let end = min(pendingIndex + maximumRecordsPerPage, pending.count)
        defer { pendingIndex = end }
        return UtteranceRecoveryBatch(
            pending: Array(pending[pendingIndex..<end]),
            quarantined: []
        )
    }

    private static func sessionReplayOrder(
        _ records: [PendingUtteranceRecord]
    ) -> [PendingUtteranceRecord] {
        let sessions = Dictionary(grouping: records, by: { $0.id.sessionID })
        let orderedSessions = sessions.keys.sorted {
            let left = sessions[$0]?.map(\.stagedAt).min() ?? .distantPast
            let right = sessions[$1]?.map(\.stagedAt).min() ?? .distantPast
            return left == right ? $0.uuidString < $1.uuidString : left < right
        }
        return orderedSessions.flatMap { sessionID in
            (sessions[sessionID] ?? []).sorted {
                if $0.id.sequenceNumber != $1.id.sequenceNumber {
                    return $0.id.sequenceNumber < $1.id.sequenceNumber
                }
                return $0.id.segmentID.uuidString < $1.id.segmentID.uuidString
            }
        }
    }
}

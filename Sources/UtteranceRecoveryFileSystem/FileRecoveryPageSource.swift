import Foundation
import UtteranceRecoveryAPI

struct FileRecoveryPageSlice: Sendable {
    let records: [PendingRecordDescriptor]
    let quarantined: [QuarantinedUtterance]
}

actor FileRecoveryPageCursor {
    private let maximumRecordsPerPage: Int
    private let records: [PendingRecordDescriptor]
    private let initialQuarantine: [QuarantinedUtterance]
    private var recordIndex = 0
    private var quarantineIndex = 0

    init(
        index: RecoveryRootIndex,
        maximumRecordsPerPage: Int
    ) {
        self.maximumRecordsPerPage = maximumRecordsPerPage
        records = index.records
        initialQuarantine = index.quarantined
    }

    func next() -> FileRecoveryPageSlice? {
        guard quarantineIndex < initialQuarantine.count || recordIndex < records.count else {
            return nil
        }
        var quarantined: [QuarantinedUtterance] = []
        while quarantined.count < maximumRecordsPerPage && quarantineIndex < initialQuarantine.count {
            quarantined.append(initialQuarantine[quarantineIndex])
            quarantineIndex += 1
        }
        let capacity = maximumRecordsPerPage - quarantined.count
        let end = min(recordIndex + capacity, records.count)
        let pageRecords = Array(records[recordIndex..<end])
        recordIndex = end
        return FileRecoveryPageSlice(records: pageRecords, quarantined: quarantined)
    }
}

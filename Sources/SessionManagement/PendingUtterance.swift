import Foundation
import SessionManagementAPI
import TranscriptAPI
import UtteranceRecoveryAPI
import VADAPI

struct PendingUtterance: Sendable {
    let segmentID: UUID
    let sequenceNumber: UInt64
    let sampleCount: Int
    let issue: LiveSessionIssue
    let translatedEntry: TranscriptEntry?
    let recoveryID: PendingUtteranceID?

    init(
        segment: SpeechSegment,
        issue: LiveSessionIssue,
        translatedEntry: TranscriptEntry?,
        recoveryID: PendingUtteranceID?
    ) {
        segmentID = segment.id
        sequenceNumber = segment.sequenceNumber
        sampleCount = segment.samples.count
        self.issue = issue
        self.translatedEntry = translatedEntry
        self.recoveryID = recoveryID
    }
}

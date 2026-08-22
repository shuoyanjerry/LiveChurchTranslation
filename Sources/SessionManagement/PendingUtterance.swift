import SessionManagementAPI
import TranscriptAPI
import UtteranceRecoveryAPI
import VADAPI

struct PendingUtterance: Sendable {
    let segment: SpeechSegment
    let issue: LiveSessionIssue
    let translatedEntry: TranscriptEntry?
    let recoveryID: PendingUtteranceID?
}

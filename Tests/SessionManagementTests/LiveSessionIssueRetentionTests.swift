@testable import SessionManagement
import SessionManagementAPI
import Testing

@Suite struct LiveSessionIssueRetentionTests {
    @Test func issueHistoryPreservesFirstCauseRecentWindowAndSuppressedCount() {
        var state = LiveSessionStateMachine()
        for sequence in 0..<40 {
            state.record(
                LiveSessionIssue(
                    stage: .translation,
                    utteranceSequence: UInt64(sequence),
                    message: "rejected",
                    isRecoverable: true
                )
            )
        }

        #expect(state.snapshot.issues.count == 32)
        #expect(state.snapshot.issues.first?.utteranceSequence == 0)
        #expect(state.snapshot.issues[state.snapshot.issues.count - 2].utteranceSequence == 39)
        #expect(state.snapshot.issues.last?.message.contains("9 条处理问题") == true)
    }
}

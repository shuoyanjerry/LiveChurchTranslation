import Foundation
@testable import SessionManagement
import Testing

@Suite struct LiveSessionRecordingStateTests {
    @Test func captureTimeClearsWhenRecordingStopsBeforeFinalization() {
        var state = LiveSessionStateMachine()
        state.begin(sessionID: UUID())
        state.markCaptureStarted(at: Date())
        state.transition(to: .stopping, message: "正在完成当前语句…")

        state.markCaptureStopped()

        #expect(state.snapshot.phase == .stopping)
        #expect(state.snapshot.captureStartedAt == nil)
    }
}

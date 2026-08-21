import SessionManagementAPI
import Testing

@Suite struct SessionManagementSmokeTests {
    @Test func idleSnapshotHasNoSession() {
        let snapshot = LiveSessionSnapshot(
            sessionID: nil,
            phase: .idle,
            transcript: [],
            modelStatus: nil,
            statusMessage: "Ready"
        )
        #expect(snapshot.sessionID == nil)
        #expect(snapshot.phase == .idle)
    }
}

import RemoteControlAPI
import RemoteControlCore
import RemoteSharingAPI
import Testing

@Suite("Revision-checked remote commands")
struct RemoteControlCoreTests {
    @Test("Only one command wins an expected-revision race and replay is idempotent")
    func raceAndReplay() async {
        let sharing = ControlSharingFake()
        let target = MutationTargetFake()
        let handler = RevisionCheckedRemoteCommandHandler(
            revisionReader: RevisionFake(revision: 9),
            sharing: sharing,
            target: target
        )
        let authorization = RemoteControlAuthorization(
            peerID: .init(), grantID: .init(), role: .operator
        )
        let first = RemoteControlRequest(command: .start, expectedRevision: 9)
        let second = RemoteControlRequest(command: .stop, expectedRevision: 9)
        let results = await withTaskGroup(of: RemoteControlResult.self) { group in
            group.addTask { await handler.handle(first, authorization: authorization) }
            group.addTask { await handler.handle(second, authorization: authorization) }
            var values: [RemoteControlResult] = []
            for await result in group { values.append(result) }
            return values
        }
        #expect(results.filter(\.accepted).count == 1)
        #expect(results.contains { $0.rejection == .staleRevision })
        let replay = await handler.handle(first, authorization: authorization)
        #expect(replay == results.first { $0.requestID == first.requestID })
        #expect(await target.calls() == 1)
    }

    @Test("A viewer is rejected without touching the target")
    func viewerDenied() async {
        let target = MutationTargetFake()
        let handler = RevisionCheckedRemoteCommandHandler(
            revisionReader: RevisionFake(revision: 1),
            sharing: ControlSharingFake(),
            target: target
        )
        let result = await handler.handle(
            .init(command: .start, expectedRevision: 1),
            authorization: .init(peerID: .init(), grantID: .init(), role: .viewer)
        )
        #expect(result.rejection == .viewerIsReadOnly)
        #expect(await target.calls() == 0)
    }
}

private struct RevisionFake: RemoteRevisionReading {
    let revision: UInt64
    func currentRemoteRevision() async -> UInt64 { revision }
}

private actor ControlSharingFake: RemoteSharingControlling {
    private var enabled = true
    func isEnabled() -> Bool { enabled }
    func setEnabled(_ enabled: Bool) { self.enabled = enabled }
}

private actor MutationTargetFake: RemoteSessionMutationTarget {
    private var count = 0
    func startRemoteSession() { count += 1 }
    func stopRemoteSession() { count += 1 }
    func calls() -> Int { count }
}

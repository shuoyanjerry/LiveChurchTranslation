import AudioCaptureAPI
import Foundation
import RemoteSharingAPI
import SessionManagementAPI

enum ProjectionAdapterTestError: Error { case timedOut }

actor ProjectionSessionControllerFake: LiveSessionController {
    private let initial: LiveSessionSnapshot
    private var continuation: AsyncStream<LiveSessionEvent>.Continuation?

    init(initial: LiveSessionSnapshot) { self.initial = initial }

    func start(inputDeviceID _: AudioInputID?) {}
    func stop() {}
    func currentSnapshot() -> LiveSessionSnapshot { initial }

    func events() -> AsyncStream<LiveSessionEvent> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.yield(.stateChanged(initial))
        }
    }

    func emit(_ event: LiveSessionEvent) { continuation?.yield(event) }
}

actor ProjectionUpdateFake: RemoteProjectionUpdating {
    private var sessionIDs: [UUID] = []
    private var stateMessages: [String] = []
    private var projectedEntries: [RemoteProjectionEntryInput] = []

    func beginSession(id: UUID, message _: String) { sessionIDs.append(id) }

    func updateState(phase _: RemoteSessionPhase, message: String) {
        stateMessages.append(message)
    }

    func upsert(_ input: RemoteProjectionEntryInput) -> RemoteTranscriptEntry {
        projectedEntries.append(input)
        return RemoteTranscriptEntry(
            id: input.id,
            sequence: input.sequence,
            revision: UInt64(projectedEntries.count),
            sourceText: input.sourceText,
            targetText: input.targetText,
            createdAt: input.createdAt
        )
    }

    func heartbeat() {}
    func sessions() -> [UUID] { sessionIDs }
    func messages() -> [String] { stateMessages }
    func entries() -> [RemoteProjectionEntryInput] { projectedEntries }
}

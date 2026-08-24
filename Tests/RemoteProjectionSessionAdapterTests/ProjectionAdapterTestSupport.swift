import AudioCaptureAPI
import Foundation
import RemoteSharingAPI
import SessionManagementAPI

enum ProjectionAdapterTestError: Error { case timedOut }

private struct ProjectedSession {
    let id: UUID
    let sourceLanguage: String?
    let targetLanguage: String?
}

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
    private var projectedSessions: [ProjectedSession] = []
    private var stateMessages: [String] = []
    private var stateLanguagePairs: [(String?, String?)] = []
    private var projectedEntries: [RemoteProjectionEntryInput] = []

    func beginSession(
        id: UUID,
        message _: String,
        sourceLanguage: String?,
        targetLanguage: String?
    ) {
        projectedSessions.append(
            ProjectedSession(
                id: id,
                sourceLanguage: sourceLanguage,
                targetLanguage: targetLanguage
            )
        )
    }

    func updateState(
        phase _: RemoteSessionPhase,
        message: String,
        sourceLanguage: String?,
        targetLanguage: String?
    ) {
        stateMessages.append(message)
        stateLanguagePairs.append((sourceLanguage, targetLanguage))
    }

    func upsert(_ input: RemoteProjectionEntryInput) -> RemoteTranscriptEntry {
        projectedEntries.append(input)
        return RemoteTranscriptEntry(
            id: input.id,
            sequence: input.sequence,
            revision: UInt64(projectedEntries.count),
            sourceText: input.sourceText,
            targetText: input.targetText,
            createdAt: input.createdAt,
            startedMilliseconds: input.startedMilliseconds
        )
    }

    func heartbeat() {}
    func sessions() -> [UUID] { projectedSessions.map(\.id) }
    func languagePairs() -> [(String?, String?)] {
        projectedSessions.map { ($0.sourceLanguage, $0.targetLanguage) }
    }
    func messages() -> [String] { stateMessages }
    func latestStateLanguagePair() -> (String?, String?)? { stateLanguagePairs.last }
    func entries() -> [RemoteProjectionEntryInput] { projectedEntries }
}

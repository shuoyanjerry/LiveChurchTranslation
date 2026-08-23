import SessionManagementAPI
import TranscriptAPI

enum SessionEventWaitError: Error {
    case timedOut
    case streamEnded
}

enum SessionEventWaiter {
    static func eventsUntilTerminal(
        from stream: AsyncStream<LiveSessionEvent>,
        timeout: Duration = .seconds(2)
    ) async throws -> [LiveSessionEvent] {
        try await withThrowingTaskGroup(of: [LiveSessionEvent].self) { group in
            group.addTask { try await collect(from: stream) }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw SessionEventWaitError.timedOut
            }
            guard let result = try await group.next() else {
                throw SessionEventWaitError.streamEnded
            }
            group.cancelAll()
            return result
        }
    }

    private static func collect(
        from stream: AsyncStream<LiveSessionEvent>
    ) async throws -> [LiveSessionEvent] {
        var events: [LiveSessionEvent] = []
        var observedActiveSession = false
        for await event in stream {
            events.append(event)
            guard case .stateChanged(let snapshot) = event else { continue }
            observedActiveSession = observedActiveSession || snapshot.sessionID != nil
            guard observedActiveSession, snapshot.sessionID == nil else { continue }
            switch snapshot.phase {
            case .idle, .failed:
                return events
            default:
                break
            }
        }
        throw SessionEventWaitError.streamEnded
    }
}

extension Array where Element == LiveSessionEvent {
    var appendedEntries: [TranscriptEntry] {
        compactMap { event in
            guard case .transcriptAppended(let entry) = event else { return nil }
            return entry
        }
    }

    var recoverableErrors: [String] {
        compactMap { event in
            guard case .recoverableError(let message) = event else { return nil }
            return message
        }
    }
}

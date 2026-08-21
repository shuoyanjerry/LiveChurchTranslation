import ASRAPI
import Foundation
import TranscriptAPI
import TranslationAPI

public actor LiveTranscriptBuffer: TranscriptBuffer {
    private var session: TranscriptSession?
    private var continuations: [UUID: AsyncStream<TranscriptEvent>.Continuation] = [:]

    public init() {}

    public func begin(sessionID: UUID, at date: Date) async {
        let newSession = TranscriptSession(
            id: sessionID,
            startedAt: date,
            endedAt: nil,
            entries: []
        )
        session = newSession
        publish(.reset(newSession))
    }

    public func makeEntry(
        recognition: RecognizedUtterance,
        translation: TranslationResult
    ) async throws -> TranscriptEntry {
        guard session != nil else { throw TranscriptBufferError.noActiveSession }
        return entry(recognition: recognition, translation: translation)
    }

    public func append(_ entry: TranscriptEntry) async {
        guard let current = session else { return }
        session = TranscriptSession(
            id: current.id,
            startedAt: current.startedAt,
            endedAt: nil,
            entries: current.entries + [entry]
        )
        publish(.appended(entry))
    }

    public func snapshot() async -> TranscriptSession? {
        session
    }

    public func finish(at date: Date) async -> TranscriptSession? {
        guard let current = session else { return nil }
        let finished = TranscriptSession(
            id: current.id,
            startedAt: current.startedAt,
            endedAt: date,
            entries: current.entries
        )
        session = finished
        publish(.finished(finished))
        return finished
    }

    public func events() async -> AsyncStream<TranscriptEvent> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    private func entry(
        recognition: RecognizedUtterance,
        translation: TranslationResult
    ) -> TranscriptEntry {
        TranscriptEntry(
            sequence: (session?.entries.count ?? 0) + 1,
            sourceText: recognition.text,
            targetText: translation.targetText,
            startedMilliseconds: recognition.startedAt.milliseconds,
            endedMilliseconds: recognition.endedAt.milliseconds,
            translationMilliseconds: translation.duration.milliseconds
        )
    }

    private func publish(_ event: TranscriptEvent) {
        continuations.values.forEach { $0.yield(event) }
    }

    private func removeContinuation(_ id: UUID) {
        continuations.removeValue(forKey: id)
    }
}

extension Duration {
    fileprivate var milliseconds: Int64 {
        let parts = components
        let seconds = parts.seconds.multipliedReportingOverflow(by: 1_000).partialValue
        return seconds + Int64(parts.attoseconds / 1_000_000_000_000_000)
    }
}

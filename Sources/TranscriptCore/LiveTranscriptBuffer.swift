import ASRAPI
import Foundation
import TranscriptAPI
import TranslationAPI

public actor LiveTranscriptBuffer: TranscriptBuffer {
    private var session: TranscriptSession?
    private var continuations: [UUID: AsyncStream<TranscriptEvent>.Continuation] = [:]

    public init() {}

    public func begin(sessionID: UUID, at date: Date) async {
        await begin(
            sessionID: sessionID,
            at: date,
            configuration: TranscriptSessionConfiguration()
        )
    }

    public func begin(
        sessionID: UUID,
        at date: Date,
        configuration: TranscriptSessionConfiguration
    ) async {
        let newSession = TranscriptSession(
            id: sessionID,
            startedAt: date,
            endedAt: nil,
            entries: [],
            title: configuration.title,
            kind: configuration.kind,
            sourceLanguage: configuration.sourceLanguage,
            targetLanguage: configuration.targetLanguage
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

    public func makeEntry(
        recognition: RecognizedUtterance,
        translation: TranslationResult,
        sourceAudit: TranscriptSourceAudit
    ) async throws -> TranscriptEntry {
        guard session != nil else { throw TranscriptBufferError.noActiveSession }
        return entry(
            recognition: recognition,
            translation: translation,
            sourceAudit: sourceAudit
        )
    }

    public func makeEntry(
        recognition: RecognizedUtterance,
        translation: TranslationResult,
        sourceAudit: TranscriptSourceAudit,
        sourceSegmentSequence: UInt64
    ) async throws -> TranscriptEntry {
        guard session != nil else { throw TranscriptBufferError.noActiveSession }
        return entry(
            recognition: recognition,
            translation: translation,
            sourceAudit: sourceAudit,
            sourceSegmentSequence: sourceSegmentSequence
        )
    }

    public func append(_ entry: TranscriptEntry) async {
        guard let current = session else { return }
        session = TranscriptSession(
            id: current.id,
            startedAt: current.startedAt,
            endedAt: nil,
            entries: current.entries + [entry],
            title: current.title,
            kind: current.kind,
            sourceLanguage: current.sourceLanguage,
            targetLanguage: current.targetLanguage
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
            entries: current.entries,
            title: current.title,
            kind: current.kind,
            sourceLanguage: current.sourceLanguage,
            targetLanguage: current.targetLanguage
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
}

extension LiveTranscriptBuffer {
    private func entry(
        recognition: RecognizedUtterance,
        translation: TranslationResult,
        sourceAudit: TranscriptSourceAudit? = nil,
        sourceSegmentSequence: UInt64? = nil
    ) -> TranscriptEntry {
        TranscriptEntry(
            id: recognition.sourceSegmentID,
            sequence: (session?.entries.count ?? 0) + 1,
            sourceSegmentSequence: sourceSegmentSequence,
            rawSourceText: sourceAudit?.rawText,
            sourceText: recognition.text,
            sourceCorrections: sourceAudit?.corrections ?? [],
            sourcePronounDecisions: sourceAudit?.pronounDecisions ?? [],
            targetText: translation.targetText,
            translationReview: translation.review,
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

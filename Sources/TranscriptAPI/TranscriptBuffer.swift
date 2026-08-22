import ASRAPI
import Foundation
import TranslationAPI

public enum TranscriptEvent: Equatable, Sendable {
    case reset(TranscriptSession)
    case appended(TranscriptEntry)
    case finished(TranscriptSession)
}

public protocol TranscriptBuffer: Sendable {
    func begin(sessionID: UUID, at date: Date) async
    func makeEntry(
        recognition: RecognizedUtterance,
        translation: TranslationResult
    ) async throws -> TranscriptEntry
    func makeEntry(
        recognition: RecognizedUtterance,
        translation: TranslationResult,
        sourceAudit: TranscriptSourceAudit
    ) async throws -> TranscriptEntry
    func append(_ entry: TranscriptEntry) async
    func snapshot() async -> TranscriptSession?
    func finish(at date: Date) async -> TranscriptSession?
    func events() async -> AsyncStream<TranscriptEvent>
}

extension TranscriptBuffer {
    public func makeEntry(
        recognition: RecognizedUtterance,
        translation: TranslationResult,
        sourceAudit: TranscriptSourceAudit
    ) async throws -> TranscriptEntry {
        try await makeEntry(recognition: recognition, translation: translation)
    }
}

public enum TranscriptBufferError: LocalizedError, Sendable {
    case noActiveSession

    public var errorDescription: String? {
        "A transcript entry cannot be created without an active session."
    }
}

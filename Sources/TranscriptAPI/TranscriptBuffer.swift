import ASRAPI
import Foundation
import TranslationAPI

public enum TranscriptEvent: Equatable, Sendable {
    case reset(TranscriptSession)
    case appended(TranscriptEntry)
    case finished(TranscriptSession)
}

public struct TranscriptSessionConfiguration: Equatable, Sendable {
    public let kind: TranscriptSessionKind
    public let title: String?
    public let sourceLanguage: String
    public let targetLanguage: String

    public init(
        kind: TranscriptSessionKind = .live,
        title: String? = nil,
        sourceLanguage: String = "zh-Hans",
        targetLanguage: String = "en"
    ) {
        self.kind = kind
        self.title = title
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }
}

public protocol TranscriptBuffer: Sendable {
    func begin(sessionID: UUID, at date: Date) async
    func begin(
        sessionID: UUID,
        at date: Date,
        configuration: TranscriptSessionConfiguration
    ) async
    func makeEntry(
        recognition: RecognizedUtterance,
        translation: TranslationResult
    ) async throws -> TranscriptEntry
    func makeEntry(
        recognition: RecognizedUtterance,
        translation: TranslationResult,
        sourceAudit: TranscriptSourceAudit
    ) async throws -> TranscriptEntry
    func makeEntry(
        recognition: RecognizedUtterance,
        translation: TranslationResult,
        sourceAudit: TranscriptSourceAudit,
        sourceSegmentSequence: UInt64
    ) async throws -> TranscriptEntry
    func append(_ entry: TranscriptEntry) async
    func snapshot() async -> TranscriptSession?
    func finish(at date: Date) async -> TranscriptSession?
    func events() async -> AsyncStream<TranscriptEvent>
}

extension TranscriptBuffer {
    public func begin(
        sessionID: UUID,
        at date: Date,
        configuration: TranscriptSessionConfiguration
    ) async {
        await begin(sessionID: sessionID, at: date)
    }

    public func makeEntry(
        recognition: RecognizedUtterance,
        translation: TranslationResult,
        sourceAudit: TranscriptSourceAudit
    ) async throws -> TranscriptEntry {
        try await makeEntry(recognition: recognition, translation: translation)
    }

    public func makeEntry(
        recognition: RecognizedUtterance,
        translation: TranslationResult,
        sourceAudit: TranscriptSourceAudit,
        sourceSegmentSequence: UInt64
    ) async throws -> TranscriptEntry {
        try await makeEntry(
            recognition: recognition,
            translation: translation,
            sourceAudit: sourceAudit
        ).recordingSourceSegmentSequence(sourceSegmentSequence)
    }
}

public enum TranscriptBufferError: LocalizedError, Sendable {
    case noActiveSession

    public var errorDescription: String? {
        "A transcript entry cannot be created without an active session."
    }
}

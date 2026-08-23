import Foundation
import VADAPI

/// Replaceable speech-recognition boundary. Implementations own their model runtime.
public protocol ASRProvider: Sendable {
    var identifier: String { get }

    func loadModel(at location: URL) async throws
    func transcribe(_ request: ASRRequest) async throws -> RecognizedUtterance
    func unloadModel() async
}

public struct ASRRequest: Sendable {
    public let segment: SpeechSegment
    public let languageCode: String
    public let contextPrompt: String

    public init(
        segment: SpeechSegment,
        languageCode: String = "zh",
        contextPrompt: String = ""
    ) {
        self.segment = segment
        self.languageCode = languageCode
        self.contextPrompt = contextPrompt
    }
}

public struct RecognizedUtterance: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let sourceSegmentID: UUID
    /// Untouched model output retained for correction audits.
    public let rawText: String
    public let text: String
    public let confidence: Float?
    public let startedAt: Duration
    public let endedAt: Duration

    public init(
        id: UUID = UUID(),
        sourceSegmentID: UUID,
        rawText: String? = nil,
        text: String,
        confidence: Float?,
        startedAt: Duration,
        endedAt: Duration
    ) {
        self.id = id
        self.sourceSegmentID = sourceSegmentID
        self.rawText = rawText ?? text
        self.text = text
        self.confidence = confidence
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

public enum ASRError: LocalizedError, Sendable {
    case modelNotLoaded
    case emptyAudio
    case filteredNonspeech
    case promptOnlyHallucination
    case repetitiveHallucination
    case noSpeechRecognized
    case inferenceFailed(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded: "The speech recognition model is not loaded."
        case .emptyAudio: "The speech segment contains no audio."
        case .filteredNonspeech: "The segment was filtered as nonspeech."
        case .promptOnlyHallucination: "The recognizer output only its prompt terms."
        case .repetitiveHallucination: "The recognizer produced pathological repetition."
        case .noSpeechRecognized: "No speech was recognized."
        case .inferenceFailed(let message): "Speech recognition failed: \(message)"
        }
    }
}

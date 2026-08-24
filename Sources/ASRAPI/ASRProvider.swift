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

public enum ASRFailureImpact: Equatable, Sendable {
    case ignoredUtterance
    case terminalUtterance
    case runtime
}

public protocol ASRFailureImpactProviding: Error, Sendable {
    var asrFailureImpact: ASRFailureImpact { get }
    var asrFailureCode: String { get }
}

public enum ASRError: LocalizedError, ASRFailureImpactProviding, Sendable {
    case modelNotLoaded
    case emptyAudio
    case filteredNonspeech
    case promptOnlyHallucination
    case repetitiveHallucination
    case noSpeechRecognized
    case noProcessableSentences
    case inferenceFailed(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded: "尚未加载语音识别模型。"
        case .emptyAudio: "语音片段不含音频。"
        case .filteredNonspeech: "该片段已判定为非语音。"
        case .promptOnlyHallucination: "识别结果仅包含提示词，已拒绝该句。"
        case .repetitiveHallucination: "识别结果出现异常重复，已拒绝该句。"
        case .noSpeechRecognized: "未识别到语音。"
        case .noProcessableSentences: "未识别到可处理的句子。"
        case .inferenceFailed(let message): "语音识别失败：\(message)"
        }
    }

    public var asrFailureImpact: ASRFailureImpact {
        switch self {
        case .modelNotLoaded, .inferenceFailed:
            .runtime
        case .emptyAudio, .filteredNonspeech, .promptOnlyHallucination,
            .repetitiveHallucination, .noSpeechRecognized, .noProcessableSentences:
            .terminalUtterance
        }
    }

    public var asrFailureCode: String {
        switch self {
        case .modelNotLoaded: "asr.model_not_loaded"
        case .emptyAudio: "asr.empty_audio"
        case .filteredNonspeech: "asr.filtered_nonspeech"
        case .promptOnlyHallucination: "asr.prompt_only_hallucination"
        case .repetitiveHallucination: "asr.repetitive_hallucination"
        case .noSpeechRecognized: "asr.no_speech_recognized"
        case .noProcessableSentences: "asr.no_processable_sentences"
        case .inferenceFailed: "asr.inference_failed"
        }
    }
}

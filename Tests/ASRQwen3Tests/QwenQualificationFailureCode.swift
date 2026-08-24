import ASRAPI
import Foundation

enum QwenQualificationFailureCode {
    static func value(for error: Error) -> String {
        if error is CancellationError { return "system.cancelled" }
        guard let error = error as? ASRError else { return "asr.unexpected_error" }
        return value(for: error)
    }

    private static func value(for error: ASRError) -> String {
        switch error {
        case .modelNotLoaded: return "asr.model_not_loaded"
        case .emptyAudio: return "asr.empty_audio"
        case .filteredNonspeech: return "asr.filtered_nonspeech"
        case .promptOnlyHallucination: return "asr.prompt_only_hallucination"
        case .repetitiveHallucination: return "asr.repetitive_hallucination"
        case .noSpeechRecognized: return "asr.no_speech_recognized"
        case .noProcessableSentences: return "asr.no_processable_sentences"
        case .inferenceFailed: return "asr.inference_failed"
        }
    }
}

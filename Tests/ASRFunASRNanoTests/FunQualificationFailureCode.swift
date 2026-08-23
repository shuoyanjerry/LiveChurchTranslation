import ASRAPI
import Foundation

enum FunQualificationFailureCode {
    static func value(for error: Error) -> String {
        if error is CancellationError { return "system.cancelled" }
        if let error = error as? FunQualificationSegmentError {
            return value(for: error)
        }
        guard let error = error as? ASRError else { return "asr.unexpected_error" }
        return value(for: error)
    }

    private static func value(for error: ASRError) -> String {
        switch error {
        case .modelNotLoaded: "asr.model_not_loaded"
        case .emptyAudio: "asr.empty_audio"
        case .filteredNonspeech: "asr.filtered_nonspeech"
        case .promptOnlyHallucination: "asr.prompt_only_hallucination"
        case .repetitiveHallucination: "asr.repetitive_hallucination"
        case .noSpeechRecognized: "asr.no_speech_recognized"
        case .inferenceFailed: "asr.inference_failed"
        }
    }

    private static func value(for error: FunQualificationSegmentError) -> String {
        switch error {
        case .unknownEndReason: "qualification.unknown_end_reason"
        case .invalidSequence: "qualification.invalid_sequence"
        case .unsafeClipID: "qualification.unsafe_clip_id"
        }
    }
}

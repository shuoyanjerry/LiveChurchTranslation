import ASRAPI
import Foundation
import Testing

@Suite("Qwen qualification failure codes")
struct QwenQualificationFailureCodeTests {
    @Test("maps every public ASR error to a stable redacted code")
    func mapsASRErrors() {
        #expect(code(.modelNotLoaded) == "asr.model_not_loaded")
        #expect(code(.emptyAudio) == "asr.empty_audio")
        #expect(code(.filteredNonspeech) == "asr.filtered_nonspeech")
        #expect(code(.promptOnlyHallucination) == "asr.prompt_only_hallucination")
        #expect(code(.repetitiveHallucination) == "asr.repetitive_hallucination")
        #expect(code(.noSpeechRecognized) == "asr.no_speech_recognized")
        #expect(code(.noProcessableSentences) == "asr.no_processable_sentences")
        #expect(code(.inferenceFailed("/private/model: secret")) == "asr.inference_failed")
    }

    @Test("redacts all details from an unexpected error")
    func redactsUnexpectedErrors() {
        let error = NSError(
            domain: "private.path./Users/person/model",
            code: 42,
            userInfo: [NSLocalizedDescriptionKey: "secret model error"]
        )

        #expect(QwenQualificationFailureCode.value(for: error) == "asr.unexpected_error")
    }

    private func code(_ error: ASRError) -> String {
        QwenQualificationFailureCode.value(for: error)
    }
}

import ASRAPI
import Testing
import TranslationAPI

@Suite struct ProviderFailureClassificationTests {
    @Test func asrFailuresHaveStableDispositionAndCode() {
        #expect(ASRError.filteredNonspeech.asrFailureImpact == .terminalUtterance)
        #expect(ASRError.emptyAudio.asrFailureImpact == .terminalUtterance)
        #expect(ASRError.promptOnlyHallucination.asrFailureImpact == .terminalUtterance)
        #expect(ASRError.repetitiveHallucination.asrFailureImpact == .terminalUtterance)
        #expect(ASRError.noSpeechRecognized.asrFailureImpact == .terminalUtterance)
        #expect(ASRError.noProcessableSentences.asrFailureImpact == .terminalUtterance)
        #expect(ASRError.modelNotLoaded.asrFailureImpact == .runtime)
        #expect(ASRError.inferenceFailed("timeout").asrFailureImpact == .runtime)
        #expect(ASRError.filteredNonspeech.asrFailureCode == "asr.filtered_nonspeech")
        #expect(ASRError.noSpeechRecognized.asrFailureCode == "asr.no_speech_recognized")
        #expect(
            ASRError.noProcessableSentences.asrFailureCode == "asr.no_processable_sentences"
        )
    }

    @Test func translationFailuresHaveStableDispositionAndCode() {
        #expect(
            TranslationProviderError.emptySource.translationFailureImpact
                == .terminalUtterance
        )
        #expect(
            TranslationProviderError.invalidOutput.translationFailureImpact
                == .retryableUtterance
        )
        #expect(
            TranslationProviderError.languageModelUnavailable.translationFailureImpact
                == .runtime
        )
        #expect(TranslationProviderError.runtimeNotAttached.translationFailureImpact == .runtime)
        #expect(
            TranslationProviderError.translationFailed("timeout").translationFailureImpact
                == .runtime
        )
        #expect(
            TranslationProviderError.invalidOutput.translationFailureCode
                == "translation.invalid_output"
        )
    }
}

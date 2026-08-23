import Testing
@testable import TranslationHyMT2
import TranslationAPI

@Suite struct HyMT2FailureImpactTests {
    @Test func unsafeInputIsTerminalAndMissingSafeOutputRemainsRetryable() {
        #expect(HyMT2Error.invalidInput.translationFailureImpact == .terminalUtterance)
        #expect(
            HyMT2Error.invalidOutput(["negation"]).translationFailureImpact
                == .retryableUtterance
        )
        #expect(HyMT2Error.invalidInput.translationFailureCode == "hymt2.invalid_input")
        #expect(
            HyMT2Error.invalidOutput(["negation"]).translationFailureCode
                == "hymt2.invalid_output"
        )
    }

    @Test func runtimeFailuresInterruptThePipeline() {
        #expect(HyMT2Error.modelNotLoaded.translationFailureImpact == .runtime)
        #expect(HyMT2Error.serverTerminated.translationFailureImpact == .runtime)
        #expect(HyMT2Error.transportFailure("timeout").translationFailureImpact == .runtime)
        #expect(HyMT2Error.malformedResponse.translationFailureImpact == .runtime)
    }
}

import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMT2PronounCollisionTests {
    @Test func rejectsReservedProtocolPrefixAcrossPromptInputs() {
        assertCollision(input(source: "<QLR_FAKE>他"), expectedField: "current source")
        assertCollision(input(source: "qlr_fake 他"), expectedField: "current source")
        assertCollision(input(source: "ＱＬＲ＿fake 他"), expectedField: "current source")
        assertCollision(input(source: "Q\u{200B}LR_fake 他"), expectedField: "current source")
        assertCollision(
            input(
                context: [
                    TranslationContextEntry(sourceText: "先前", targetText: "</QLR_FAKE>")
                ]
            ),
            expectedField: "translation context"
        )
        assertCollision(
            input(
                protocolTerms: [
                    TranslationTerm(source: "他", target: "<QLR_FAKE>")
                ]
            ),
            expectedField: "glossary"
        )
    }

    private func input(
        source: String = "他继续。",
        protocolTerms: [TranslationTerm] = [],
        context: [TranslationContextEntry] = []
    ) -> HyMT2TranslationInput {
        HyMT2TranslationInput(
            source: source,
            targetLanguage: "en",
            terms: [],
            protocolTerms: protocolTerms,
            context: context,
            pronounGuidance: [guidance(0, .unresolvedSpokenMandarin)]
        )
    }

    private func assertCollision(
        _ input: HyMT2TranslationInput,
        expectedField: String
    ) {
        do {
            _ = try input.prepared(requestID: pronounTestRequestID)
            Issue.record("Expected marker collision rejection")
        } catch let failure as OutputValidationFailure {
            #expect(failure.issues == [.reservedPronounMarkerCollision(expectedField)])
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

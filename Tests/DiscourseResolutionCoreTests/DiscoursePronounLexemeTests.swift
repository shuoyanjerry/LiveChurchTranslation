import DiscourseResolutionAPI
import DiscourseResolutionCore
import Testing

@Suite struct DiscoursePronounLexemeTests {
    private let resolver = DiscourseResolver()

    @Test func lexicalOccurrenceDoesNotHideIndependentPronoun() {
        let result = resolver.resolve(
            DiscourseResolutionRequest(
                currentSequence: 10,
                currentText: "姐妹到了，所以他告诉其他人。",
                verifiedTurns: []
            )
        )

        #expect(result.resolvedText == "姐妹到了，所以她告诉其他人。")
        #expect(result.constraints.contains(.lexicalOccurrenceProtected))
        #expect(isVerifiedFemale(result.pronounGuidance.first?.resolution))
    }

    @Test func singularObjectGlyphStaysOutsideHumanGenderResolution() {
        let result = resolve("它会继续。")

        #expect(result.resolvedText == result.originalText)
        #expect(result.corrections.isEmpty)
        #expect(result.pronounGuidance.isEmpty)
    }

    @Test func pluralAndLexicalObjectGlyphsAreProtected() {
        for text in ["它们会继续。", "它們会继续。", "它俩会继续。", "其它事情以后再说。"] {
            let result = resolve(text)

            #expect(result.resolvedText == text)
            #expect(result.pronounGuidance.isEmpty)
            #expect(result.constraints.contains(.lexicalOccurrenceProtected))
        }
    }

    private func resolve(_ text: String) -> DiscourseResolutionResult {
        resolver.resolve(
            DiscourseResolutionRequest(
                currentSequence: 10,
                currentText: text,
                verifiedTurns: []
            )
        )
    }

    private func isVerifiedFemale(_ resolution: DiscoursePronounResolution?) -> Bool {
        guard case .verified(let gender, _, _, _) = resolution else { return false }
        return gender == .female
    }

}

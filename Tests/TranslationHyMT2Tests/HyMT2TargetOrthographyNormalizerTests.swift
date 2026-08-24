import Testing
@testable import TranslationHyMT2

@Suite struct HyMT2TargetOrthographyNormalizerTests {
    @Test func normalizesSafeChinesePunctuationInEnglishTranslation() throws {
        let target = try HyMT2OutputValidator.validate(
            "The church receives grace、peace，and hope。",
            source: "教会领受恩典、平安和盼望。",
            requiredTerms: []
        )

        #expect(target == "The church receives grace, peace, and hope.")
    }

    @Test func normalizesBookTitlePunctuationWithoutAllowingHanText() throws {
        let target = try HyMT2OutputValidator.validate(
            "The sermon title is 《Grace and Peace》：an introduction。",
            source: "讲道题目是《恩典与平安》：引言。",
            requiredTerms: []
        )

        #expect(target == "The sermon title is \"Grace and Peace\": an introduction.")
        #expect(
            validationIssues("The sermon is about 恩典。").contains(.unexpectedSourceScript)
        )
    }

    private func validationIssues(_ output: String) -> [OutputValidationIssue] {
        do {
            _ = try HyMT2OutputValidator.validate(
                output,
                source: "这篇讲道谈到恩典。",
                requiredTerms: []
            )
            return []
        } catch let failure as OutputValidationFailure {
            return failure.issues
        } catch {
            Issue.record("Unexpected error: \(error)")
            return []
        }
    }
}

import Foundation
import Testing
import TranslationAPI
@testable import TranslationHyMT2

@Suite struct HyMTQualificationFailureCodeTests {
    @Test func mapsEveryKnownStrictCategoryToFixedCode() {
        let fixtures: [(String, String)] = [
            ("empty output", "empty"),
            ("implausible output length", "len"),
            ("model commentary or instruction text", "meta"),
            ("prompt-control delimiter remains in output", "ctl"),
            ("Chinese source script remains in English output", "zh"),
            ("missing required term", "term"),
            ("missing required term: private-term", "term"),
            ("missing source number", "num"),
            ("missing number: 8675309", "num"),
            ("source negation was not preserved", "neg"),
            ("Scripture reference was not preserved", "verse"),
            ("pronoun marker P9999 expected secret", "pron"),
            ("unrecognized private detail", "other"),
        ]

        for (reason, suffix) in fixtures {
            #expect(code([reason]) == "hymt.strict.\(suffix)")
        }
    }

    @Test func combinationOrderAndDeduplicationAreStable() {
        let reasons = [
            "unrecognized detail",
            "missing number: 99",
            "pronoun marker P0007 expected private",
            "Chinese source script remains in English output",
            "missing required term: private",
            "missing number: 99",
            "empty output",
        ]

        let value = code(reasons)

        #expect(value == "hymt.strict.empty.zh.term.num.pron.other")
        #expect(isSafeReportCode(value))
    }

    @Test func sensitiveSuffixesNeverEnterFailureCode() {
        let secrets = ["圣灵", "4111111111111111", "P9876", "raw-sermon-phrase"]
        let reasons = [
            "missing required term: \(secrets[0])",
            "missing number: \(secrets[1])",
            "pronoun marker \(secrets[2]) expected verifiedMale, observed raw",
            secrets[3],
        ]

        let value = code(reasons)

        #expect(
            value
                == "hymt.strict.term.num.pron.other"
        )
        #expect(secrets.allSatisfy { !value.contains($0) })
        #expect(!value.contains("verifiedMale"))
        #expect(!value.contains("observed"))
    }

    @Test func everyProductionPronounDescriptionMapsToOneFixedCategory() {
        let range = TranslationSourceRange(location: 7, length: 1)
        let issues: [OutputValidationIssue] = [
            .negativePronounSourceRange(-1, 1),
            .emptyPronounSourceRange(7),
            .pronounSourceRangeOutOfBounds(7, 99),
            .pronounSourceRangeNotOnCharacterBoundary(7, 1),
            .duplicatePronounSourceRange(7, 1),
            .overlappingPronounSourceRanges(7, 8),
            .pronounSourceRangeWrongGlyph(7),
            .tooManyPronounOccurrences(10_000),
            .reservedPronounMarkerCollision("private-field"),
            .missingPronounMarker("P0001", range, .verifiedFemale),
            .duplicatePronounMarker("P0001"),
            .unknownPronounMarker("P9999"),
            .malformedPronounMarker,
            .pronounMarkerResolutionMismatch("P0001"),
            .reusedPronounRealization("P0001"),
            .wrongPronounRealization("P0001", range, .verifiedFemale, .male),
        ]

        for issue in issues {
            #expect(
                code([issue.description])
                    == "hymt.strict.pron",
                "Unclassified production reason: \(issue.description)"
            )
        }
    }

    @Test func nearMatchesAndEmptyReasonListFailClosedToOther() {
        let nearMatches = [
            "empty output private",
            "missing required term private",
            "missing source number private",
            "missing number:",
            "pronounish marker P0001",
        ]

        #expect(code([]) == "hymt.strict.other")
        #expect(code(nearMatches) == "hymt.strict.other")
    }

    private func code(_ reasons: [String]) -> String {
        HyMTQualificationFailureCode.make(HyMT2Error.invalidOutput(reasons))
    }

    private func isSafeReportCode(_ value: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._-")
        return !value.isEmpty
            && value.count <= 64
            && value.unicodeScalars.allSatisfy(allowed.contains)
    }
}

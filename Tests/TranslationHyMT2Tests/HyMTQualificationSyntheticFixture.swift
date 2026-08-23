import Foundation
import TranslationAPI
import TranslationQualificationSupport
@testable import TranslationHyMT2

enum HyMTQualificationSyntheticFixture {
    static func unresolvedPronounOutput() throws -> String {
        let plan = try makePronounPlan(
            source: "他仍在这里。",
            guidance: [guidance(0, .unresolvedSpokenMandarin)]
        )
        return "\(anchored(plan, 0, "They")) remain present."
    }

    static func segments() throws -> [TranslationQualificationSegment] {
        try (1...4).map { sequence in
            let heading = sequence == 1
            let id = "synthetic-\(sequence)"
            let value: [String: Any] = [
                "id": id, "sourceID": "synthetic-source", "sequence": sequence,
                "unitKind": heading ? "sectionHeading" : "content",
                "referenceProfileID": "synthetic-profile",
                "discourseContextIDs": sequence == 1 ? [] : ["synthetic-\(sequence - 1)"],
                "locator": ["chinesePages": [1], "englishPages": [1]],
                "originalChinese": heading ? "合成标题" : "他仍在这里。",
                "observedASRAmbiguousChinese": heading ? "合成标题" : "他仍在这里。",
                "referenceEnglish": "Reference-only marker \(id)",
                "featureTags": heading ? [] : ["taAmbiguity"], "theologyTerms": [],
                "pronounOccurrences": heading ? [] : [occurrence(id)], "referenceWarnings": [],
                "qualification": [
                    "semanticScoringEligible": !heading, "exactStringScoringEligible": false,
                    "asrCEREligible": false, "requiresHumanSemanticReview": !heading,
                ],
            ]
            let data = try JSONSerialization.data(withJSONObject: value)
            return try JSONDecoder().decode(TranslationQualificationSegment.self, from: data)
        }
    }

    private static func occurrence(_ segmentID: String) -> [String: Any] {
        [
            "id": "\(segmentID)-ta", "unicodeScalarOffset": 0, "originalGlyph": "他",
            "observedGlyph": "他", "tokenClass": "singularPronoun", "antecedentLabel": NSNull(),
            "evidenceScope": "noneAtDecisionTime", "expectedGuidance": "unresolved",
            "expectedEnglishStrategy": "singularTheyOrLexicalAntecedentRequired",
            "mustAbstainWhenEvidenceMissing": true, "rationaleCode": "syntheticNoEvidence",
        ]
    }
}

import Foundation
import TranslationQualificationSupport

enum HyMTNegationDiagnosticTestFixture {
    static func segments() throws -> [TranslationQualificationSegment] {
        try [
            segment(
                id: "negation-synthetic-1",
                sequence: 1,
                chinese: "公开合成背景。",
                reference: "Public synthetic background."
            ),
            segment(
                id: "negation-synthetic-2",
                sequence: 2,
                chinese: "公开合成内容。",
                reference: "Public synthetic content."
            ),
            segment(
                id: "negation-synthetic-3",
                sequence: 3,
                chinese: "工作不可停止。",
                reference: "Stopping the work is forbidden."
            ),
        ]
    }

    private static func segment(
        id: String,
        sequence: Int,
        chinese: String,
        reference: String
    ) throws -> TranslationQualificationSegment {
        let value: [String: Any] = [
            "id": id, "sourceID": "negation-synthetic-source", "sequence": sequence,
            "unitKind": "content", "referenceProfileID": "synthetic-profile",
            "discourseContextIDs": [],
            "locator": ["chinesePages": [1], "englishPages": [1]],
            "originalChinese": chinese, "observedASRAmbiguousChinese": chinese,
            "referenceEnglish": reference, "featureTags": [], "theologyTerms": [],
            "pronounOccurrences": [], "referenceWarnings": [],
            "qualification": [
                "semanticScoringEligible": true, "exactStringScoringEligible": false,
                "asrCEREligible": false, "requiresHumanSemanticReview": true,
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: value)
        return try JSONDecoder().decode(TranslationQualificationSegment.self, from: data)
    }

}

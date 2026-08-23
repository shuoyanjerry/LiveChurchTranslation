import Foundation

extension SyntheticTranslationManifestFactory {
    static var rights: [String: Any] {
        [
            "classification": "officialDirectDownloadNoOpenReuseLicenseObserved",
            "evidenceURL": "https://example.invalid/rights", "localPrivateQAAllowed": true,
            "trainingAllowed": false, "redistributionAllowed": false, "mustNotCommit": true,
        ]
    }

    static func segments(requiresHumanReview: Bool) -> [[String: Any]] {
        ["source-a", "source-b"].flatMap { sourceID in
            (1...50).map {
                segment(
                    sourceID,
                    sequence: $0,
                    requiresHumanReview: requiresHumanReview
                )
            }
        }
    }

    private static func segment(
        _ sourceID: String,
        sequence: Int,
        requiresHumanReview: Bool
    ) -> [String: Any] {
        let id = "\(sourceID)-\(sequence)"
        let heading = sequence == 1
        let prior = max(1, sequence - 3)..<sequence
        return [
            "id": id, "sourceID": sourceID, "sequence": sequence,
            "unitKind": heading ? "sectionHeading" : "content",
            "referenceProfileID": sourceID == "source-a" ? "profile-a" : "profile-b",
            "discourseContextIDs": sequence == 1 ? [] : prior.map { "\(sourceID)-\($0)" },
            "locator": ["chinesePages": [1], "englishPages": [1]],
            "originalChinese": heading ? "合成标题" : "他在这里。",
            "observedASRAmbiguousChinese": heading ? "合成标题" : "他在这里。",
            "referenceEnglish": "Reference-only marker \(id)",
            "featureTags": heading ? [] : ["taAmbiguity"],
            "theologyTerms": heading ? [] : ["这里"],
            "pronounOccurrences": heading ? [] : [occurrence(id)], "referenceWarnings": [],
            "qualification": qualification(
                heading: heading,
                requiresHumanReview: requiresHumanReview
            ),
        ]
    }

    private static func occurrence(_ segmentID: String) -> [String: Any] {
        [
            "id": "\(segmentID)-ta-1", "unicodeScalarOffset": 0, "originalGlyph": "他",
            "observedGlyph": "他", "tokenClass": "singularPronoun", "antecedentLabel": NSNull(),
            "evidenceScope": "noneAtDecisionTime", "expectedGuidance": "unresolved",
            "expectedEnglishStrategy": "singularTheyOrLexicalAntecedentRequired",
            "mustAbstainWhenEvidenceMissing": true, "rationaleCode": "syntheticNoEvidence",
        ]
    }

    private static func qualification(
        heading: Bool,
        requiresHumanReview: Bool
    ) -> [String: Any] {
        [
            "semanticScoringEligible": !heading && requiresHumanReview,
            "exactStringScoringEligible": false, "asrCEREligible": false,
            "requiresHumanSemanticReview": !heading && requiresHumanReview,
        ]
    }

    static var summary: [String: Any] {
        [
            "sourceCount": 2, "segmentPairCount": 100, "contentPairCount": 98,
            "headingOrTitlePairCount": 2,
            "sourcePairCounts": [
                ["sourceID": "source-a", "count": 50],
                ["sourceID": "source-b", "count": 50],
            ],
            "featureTagCounts": [["tag": "taAmbiguity", "count": 98]],
            "taGlyphOccurrenceCount": 98,
            "pronounGuidanceCounts": [["guidance": "unresolved", "count": 98]],
            "grnCandidateCount": 0, "hesedExcludedCount": 0,
        ]
    }

    static let assetPath = ".artifacts/synthetic/source.bin"
}

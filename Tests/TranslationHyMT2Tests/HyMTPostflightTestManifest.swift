import Foundation

extension HyMTPostflightTestFixture {
    static var manifest: [String: Any] {
        [
            "schemaVersion": 1, "schemaPath": ".artifacts/synthetic/schema.json",
            "corpusID": "synthetic-postflight-corpus", "generatedAt": "2026-08-22T12:00:00Z",
            "visibility": "synthetic", "provenance": provenanceMetadata,
            "policy": policy, "referenceProfiles": [], "sources": [],
            "segments": [segment], "candidateSources": [], "summary": summary,
        ]
    }

    private static var provenanceMetadata: [String: Any] {
        [
            "parentCorpusManifestPath": ".artifacts/synthetic/parent.json",
            "parentCorpusManifestSHA256": sha("c"), "searchProvider": "synthetic",
            "sourcesReviewedInParentResearch": 1, "latestExtensionStatus": "synthetic",
            "builderSHA256": sha("d"), "configSHA256": sha("e"),
            "candidateConfigSHA256": sha("f"), "supportSHA256": sha("0"),
        ]
    }

    private static var policy: [String: Any] {
        [
            "taDegradation": "synthetic", "genderRule": "evidence only",
            "referenceRule": "review only", "copyrightRule": "synthetic only",
        ]
    }

    private static var segment: [String: Any] {
        [
            "id": "synthetic-1", "sourceID": "synthetic-source", "sequence": 1,
            "unitKind": "sectionHeading", "referenceProfileID": "synthetic-profile",
            "discourseContextIDs": [], "locator": ["chinesePages": [1], "englishPages": [1]],
            "originalChinese": "\u{5408}\u{6210}\u{6807}\u{9898}",
            "observedASRAmbiguousChinese": "\u{5408}\u{6210}\u{6807}\u{9898}",
            "referenceEnglish": "Synthetic reference", "featureTags": [], "theologyTerms": [],
            "pronounOccurrences": [], "referenceWarnings": [],
            "qualification": [
                "semanticScoringEligible": false, "exactStringScoringEligible": false,
                "asrCEREligible": false, "requiresHumanSemanticReview": false,
            ],
        ]
    }

    private static var summary: [String: Any] {
        [
            "sourceCount": 0, "segmentPairCount": 1, "contentPairCount": 0,
            "headingOrTitlePairCount": 1, "sourcePairCounts": [], "featureTagCounts": [],
            "taGlyphOccurrenceCount": 0, "pronounGuidanceCounts": [],
            "grnCandidateCount": 0, "hesedExcludedCount": 0,
        ]
    }
}

import Foundation

enum SyntheticTranslationManifestFactory {
    static func make(
        hashes: SyntheticTranslationHashes,
        requiresHumanReview: Bool
    ) -> [String: Any] {
        [
            "schemaVersion": 1,
            "schemaPath": ".artifacts/synthetic/schema.json",
            "corpusID": "private-bilingual-mandarin-sermon-goldens-v1",
            "generatedAt": "2026-08-22T12:00:00Z",
            "visibility": "gitignoredPrivateLocalQAOnly",
            "provenance": provenance(hashes),
            "policy": policy,
            "referenceProfiles": [profile("profile-a"), profile("profile-b")],
            "sources": [
                source("source-a", profile: "profile-a", hashes),
                source("source-b", profile: "profile-b", hashes),
            ],
            "segments": segments(requiresHumanReview: requiresHumanReview),
            "candidateSources": [],
            "summary": summary,
        ]
    }

    private static func provenance(_ hashes: SyntheticTranslationHashes) -> [String: Any] {
        [
            "parentCorpusManifestPath": ".artifacts/synthetic/parent.json",
            "parentCorpusManifestSHA256": hashes.parent,
            "searchProvider": "Exa",
            "sourcesReviewedInParentResearch": 1,
            "latestExtensionStatus": "HTTP402CreditsExhaustedNoGenericSearchFallback",
            "builderSHA256": hashes.builder,
            "configSHA256": hashes.config,
            "candidateConfigSHA256": hashes.candidate,
            "supportSHA256": hashes.support,
        ]
    }

    private static var policy: [String: Any] {
        [
            "taDegradation": "synthetic ta-only degradation",
            "genderRule": "evidence only",
            "referenceRule": "review only",
            "copyrightRule": "synthetic only",
        ]
    }

    private static func profile(_ id: String) -> [String: Any] {
        [
            "id": id,
            "spokenTextClass": "publisherLabeledFullManuscript",
            "spokenAudioVerification": "synthetic",
            "translationClass": "humanInterpretiveTranslation",
            "exactStringMetricEligible": false,
            "allowedQualification": ["semantic review"],
            "forbiddenQualification": ["exact match"],
            "knownLimitations": ["synthetic fixture"],
        ]
    }

    private static func source(
        _ id: String,
        profile: String,
        _ hashes: SyntheticTranslationHashes
    ) -> [String: Any] {
        [
            "id": id, "provider": "Synthetic", "titleChinese": "合成标题",
            "titleEnglish": "Synthetic title", "speaker": "Synthetic speaker",
            "sourcePageURL": "https://example.invalid/source", "referenceURL": "https://example.invalid/ref",
            "audioURL": "https://example.invalid/audio", "audioLocalPath": assetPath,
            "audioSHA256": hashes.source, "audioAlignment": "notTimecoded",
            "referenceLocalPath": assetPath, "referenceSHA256": hashes.source,
            "extractedTextLocalPath": assetPath, "extractedTextSHA256": hashes.source,
            "pageCount": 1, "pairCount": 50, "referenceProfileID": profile,
            "rights": rights,
        ]
    }

}

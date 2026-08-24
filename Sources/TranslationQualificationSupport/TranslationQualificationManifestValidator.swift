import Foundation

public enum TranslationManifestValidator {
    public static func validate(_ manifest: TranslationQualificationManifest) throws {
        try validateIdentity(manifest)
        try validateSources(manifest)
        try validateSegments(manifest)
        try validateSummary(manifest)
    }

    private static func validateIdentity(_ manifest: TranslationQualificationManifest) throws {
        try require(manifest.schemaVersion == 1, "schemaVersion must be 1")
        try require(
            manifest.corpusID == "private-bilingual-mandarin-sermon-goldens-v1",
            "unexpected corpusID"
        )
        try require(
            manifest.visibility == "gitignoredPrivateLocalQAOnly",
            "manifest must remain private"
        )
        try require(!manifest.schemaPath.isEmpty, "schemaPath is empty")
        try require(isISO8601(manifest.generatedAt), "invalid generatedAt")
        try require(isSHA(manifest.provenance.parentCorpusManifestSHA256), "invalid parent hash")
        for hash in provenanceHashes(manifest.provenance) {
            try require(isSHA(hash), "invalid provenance hash")
        }
    }

    private static func validateSources(_ manifest: TranslationQualificationManifest) throws {
        try require(manifest.referenceProfiles.count >= 2, "too few reference profiles")
        try require(manifest.sources.count >= 2, "too few sources")
        let profileIDs = Set(manifest.referenceProfiles.map(\.id))
        try require(profileIDs.count == manifest.referenceProfiles.count, "duplicate profile ID")
        try require(
            manifest.referenceProfiles.allSatisfy { !$0.exactStringMetricEligible },
            "exact-string reference is forbidden"
        )
        var sourceIDs = Set<String>()
        for source in manifest.sources {
            try require(sourceIDs.insert(source.id).inserted, "duplicate source ID")
            try require(profileIDs.contains(source.referenceProfileID), "unknown source profile")
            try require(source.pairCount > 0 && source.pageCount > 0, "invalid source counts")
            try require(isSHA(source.audioSHA256), "invalid audio hash")
            try require(isSHA(source.referenceSHA256), "invalid reference hash")
            try require(isSHA(source.extractedTextSHA256), "invalid extracted-text hash")
            try require(source.rights.localPrivateQAAllowed, "private QA permission missing")
            try require(!source.rights.trainingAllowed, "training must be forbidden")
            try require(!source.rights.redistributionAllowed, "redistribution must be forbidden")
            try require(source.rights.mustNotCommit, "mustNotCommit must be true")
        }
    }

    private static func validateSegments(_ manifest: TranslationQualificationManifest) throws {
        try require(manifest.segments.count >= 100, "too few segments")
        let sources = Dictionary(uniqueKeysWithValues: manifest.sources.map { ($0.id, $0) })
        let profiles = Set(manifest.referenceProfiles.map(\.id))
        var segmentIDs = Set<String>()
        var seenBySource: [String: Set<String>] = [:]
        var expectedSequence: [String: Int] = [:]
        for segment in manifest.segments {
            try require(segmentIDs.insert(segment.id).inserted, "duplicate segment ID")
            try require(sources[segment.sourceID] != nil, "unknown segment source")
            try require(profiles.contains(segment.referenceProfileID), "unknown segment profile")
            let expected = expectedSequence[segment.sourceID, default: 1]
            try require(segment.sequence == expected, "noncontiguous segment sequence")
            expectedSequence[segment.sourceID] = expected + 1
            let prior = seenBySource[segment.sourceID, default: []]
            try require(segment.discourseContextIDs.count <= 3, "too much discourse context")
            try require(segment.discourseContextIDs.allSatisfy(prior.contains), "future context ID")
            try validateTextAndOccurrences(segment)
            try require(!segment.qualification.exactStringScoringEligible, "exact scoring enabled")
            try require(!segment.qualification.asrCEREligible, "CER enabled")
            try require(
                !segment.qualification.requiresHumanSemanticReview
                    || segment.qualification.semanticScoringEligible,
                "human semantic review requires semantic scoring eligibility"
            )
            seenBySource[segment.sourceID, default: []].insert(segment.id)
        }
        for source in manifest.sources {
            let count = manifest.segments.filter { $0.sourceID == source.id }.count
            try require(count == source.pairCount, "source pair count mismatch")
        }
    }

}

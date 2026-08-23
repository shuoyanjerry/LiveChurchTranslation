extension TranslationManifestValidator {
    static func validateSummary(_ manifest: TranslationQualificationManifest) throws {
        let summary = manifest.summary
        try require(summary.sourceCount == manifest.sources.count, "source summary mismatch")
        try require(summary.segmentPairCount == manifest.segments.count, "segment summary mismatch")
        let content = manifest.segments.filter { $0.unitKind == "content" }.count
        try require(summary.contentPairCount == content, "content summary mismatch")
        try require(
            summary.headingOrTitlePairCount == manifest.segments.count - content,
            "heading summary mismatch"
        )
        let occurrenceCount = manifest.segments.reduce(0) { $0 + $1.pronounOccurrences.count }
        try require(summary.taGlyphOccurrenceCount == occurrenceCount, "ta summary mismatch")
        try validateSourceCounts(manifest)
        try validateGuidanceCounts(manifest)
    }

    private static func validateSourceCounts(
        _ manifest: TranslationQualificationManifest
    ) throws {
        let pairs = manifest.summary.sourcePairCounts.compactMap { item in
            item.sourceID.map { ($0, item.count) }
        }
        try require(Set(pairs.map(\.0)).count == pairs.count, "duplicate source summary")
        let counts = Dictionary(uniqueKeysWithValues: pairs)
        for source in manifest.sources {
            let count = manifest.segments.filter { $0.sourceID == source.id }.count
            try require(counts[source.id] == count, "source count summary mismatch")
        }
    }

    private static func validateGuidanceCounts(
        _ manifest: TranslationQualificationManifest
    ) throws {
        let guidance = manifest.segments.flatMap(\.pronounOccurrences).map(\.expectedGuidance.rawValue)
        let counts = Dictionary(grouping: guidance, by: { $0 }).mapValues(\.count)
        let pairs = manifest.summary.pronounGuidanceCounts.compactMap { item in
            item.guidance.map { ($0, item.count) }
        }
        try require(Set(pairs.map(\.0)).count == pairs.count, "duplicate guidance summary")
        try require(counts == Dictionary(uniqueKeysWithValues: pairs), "guidance summary mismatch")
    }
}

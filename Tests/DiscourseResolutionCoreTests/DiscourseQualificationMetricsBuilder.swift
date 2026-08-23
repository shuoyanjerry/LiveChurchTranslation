enum DiscourseQualificationMetricsBuilder {
    static func build(
        _ segments: [DiscourseQualificationSegmentReport]
    ) -> DiscourseQualificationMetrics {
        let occurrences = segments.flatMap(\.occurrences)
        let counts = DiscourseQualificationMetricCounts(
            segments: segments,
            occurrences: occurrences
        )
        return metrics(segmentCount: segments.count, counts: counts)
    }

    private static func metrics(
        segmentCount: Int,
        counts: DiscourseQualificationMetricCounts
    ) -> DiscourseQualificationMetrics {
        DiscourseQualificationMetrics(
            segmentCount: segmentCount,
            occurrenceCount: counts.occurrenceCount,
            exactPolicyMatchCount: counts.policyMatches,
            policyMismatchCount: counts.occurrenceCount - counts.policyMatches,
            resolvableOccurrenceCount: counts.resolvable,
            correctAutomaticResolutionCount: counts.correct,
            missedResolvableCount: counts.missed,
            expectedAbstentionCount: counts.expectedAbstentions,
            safeAbstentionCount: counts.abstentions,
            protectedOccurrenceCount: counts.protected,
            safeProtectionCount: counts.protections,
            wrongAutomaticResolutionCount: counts.wrong,
            mappingFailureCount: counts.mappingFailures,
            unmappedGuidanceCount: counts.unmapped,
            resolutionCoverage: DiscourseQualificationRate(
                numerator: counts.correct,
                denominator: counts.resolvable
            ),
            abstentionSafety: DiscourseQualificationRate(
                numerator: counts.abstentions,
                denominator: counts.expectedAbstentions
            ),
            hardFailureCount: counts.wrong + counts.mappingFailures
        )
    }
}

private struct DiscourseQualificationMetricCounts {
    let occurrenceCount: Int
    let policyMatches: Int
    let resolvable: Int
    let correct: Int
    let missed: Int
    let expectedAbstentions: Int
    let abstentions: Int
    let protected: Int
    let protections: Int
    let wrong: Int
    let mappingFailures: Int
    let unmapped: Int

    init(
        segments: [DiscourseQualificationSegmentReport],
        occurrences: [DiscourseQualificationOccurrenceReport]
    ) {
        occurrenceCount = occurrences.count
        policyMatches = occurrences.filter { $0.policyStatusClass == .pass }.count
        resolvable = Self.expected(["verifiedMale", "verifiedFemale", "deity"], in: occurrences)
        correct = Self.count(.correctAutomaticResolution, in: occurrences)
        missed = Self.count(.missedResolvable, in: occurrences)
        expectedAbstentions = Self.expected(["unresolved"], in: occurrences)
        abstentions = Self.count(.safeAbstention, in: occurrences)
        protected = Self.expected(["pluralNeutral", "lexicalNotPronoun"], in: occurrences)
        protections = Self.count(.safeProtection, in: occurrences)
        wrong = Self.count(.wrongAutomaticResolution, in: occurrences)
        let unmappedCount = segments.map(\.unmappedGuidanceCount).reduce(0, +)
        unmapped = unmappedCount
        mappingFailures = Self.count(.mappingFailure, in: occurrences) + unmappedCount
    }

    private static func count(
        _ outcome: DiscourseQualificationOutcomeClass,
        in values: [DiscourseQualificationOccurrenceReport]
    ) -> Int {
        values.filter { $0.outcomeClass == outcome }.count
    }

    private static func expected(
        _ classes: Set<String>,
        in values: [DiscourseQualificationOccurrenceReport]
    ) -> Int {
        values.filter { classes.contains($0.expectedGuidanceClass) }.count
    }
}

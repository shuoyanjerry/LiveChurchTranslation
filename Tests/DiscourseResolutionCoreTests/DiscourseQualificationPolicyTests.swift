import Testing
import TranslationQualificationSupport

@Suite struct DiscourseQualificationPolicyTests {
    @Test func automaticMismatchIsAHardSafetyClass() {
        #expect(classify(.verifiedFemale, "verifiedMale") == .wrongAutomaticResolution)
        #expect(classify(.unresolved, "verifiedMale") == .wrongAutomaticResolution)
        #expect(classify(.pluralNeutral, "verifiedFemale") == .wrongAutomaticResolution)
    }

    @Test func absentEvidenceIsReportedWithoutInventingGender() {
        #expect(classify(.verifiedMale, "unresolvedSpokenMandarin") == .missedResolvable)
        #expect(classify(.deity, "none") == .missedResolvable)
        #expect(classify(.unresolved, "none") == .safeAbstention)
        #expect(classify(.lexicalNotPronoun, "none") == .safeProtection)
    }

    @Test func contextKeepsOnlyTwoCompletedTurnsPerSource() {
        var context = DiscourseQualificationContext()
        append("a1", sequence: 1, source: "a", context: &context)
        append("b1", sequence: 1, source: "b", context: &context)
        append("a2", sequence: 2, source: "a", context: &context)
        append("a3", sequence: 3, source: "a", context: &context)

        #expect(context.latest(for: "a").segmentIDs == ["a2", "a3"])
        #expect(context.latest(for: "b").segmentIDs == ["b1"])
    }

    @Test func metricsKeepEveryExpectedResolvableCaseInCoverageDenominator() {
        let segments = [
            segment(
                occurrence(.verifiedMale, actual: "verifiedMale", outcome: .correctAutomaticResolution)
            ),
            segment(
                occurrence(.verifiedFemale, actual: "none", outcome: .missedResolvable)
            ),
            segment(
                occurrence(.unresolved, actual: "verifiedMale", outcome: .wrongAutomaticResolution)
            ),
        ]
        let metrics = DiscourseQualificationMetricsBuilder.build(segments)

        #expect(metrics.resolvableOccurrenceCount == 2)
        #expect(metrics.resolutionCoverage.numeratorCount == 1)
        #expect(metrics.resolutionCoverage.denominatorCount == 2)
        #expect(metrics.wrongAutomaticResolutionCount == 1)
        #expect(metrics.hardFailureCount == 1)
    }

    private func classify(
        _ expected: TranslationExpectedPronounGuidance,
        _ actual: String
    ) -> DiscourseQualificationOutcomeClass {
        DiscourseQualificationOutcomeClassifier.classify(expected: expected, actual: actual)
    }

    private func append(
        _ id: String,
        sequence: Int,
        source: String,
        context: inout DiscourseQualificationContext
    ) {
        context.append(
            DiscourseQualificationPersistedTurn(segmentID: id, sequence: sequence, text: id),
            sourceID: source
        )
    }

    private func occurrence(
        _ expected: TranslationExpectedPronounGuidance,
        actual: String,
        outcome: DiscourseQualificationOutcomeClass
    ) -> DiscourseQualificationOccurrenceReport {
        DiscourseQualificationOccurrenceReport(
            occurrenceID: "occurrence",
            expectedGuidanceClass: expected.rawValue,
            actualGuidanceClass: actual,
            outcomeClass: outcome,
            policyStatusClass: .fail
        )
    }

    private func segment(
        _ occurrence: DiscourseQualificationOccurrenceReport
    ) -> DiscourseQualificationSegmentReport {
        DiscourseQualificationSegmentReport(
            segmentID: "segment",
            sourceID: "source",
            sequence: 1,
            inputSHA256: String(repeating: "a", count: 64),
            resolvedSHA256: String(repeating: "b", count: 64),
            contextSegmentIDs: [],
            contextTextSHA256s: [],
            correctionCount: 0,
            correctionClasses: [],
            guidanceCount: 1,
            unmappedGuidanceCount: 0,
            duplicateGuidanceLocationCount: 0,
            ambiguityClasses: [],
            constraintClasses: [],
            occurrences: [occurrence]
        )
    }
}

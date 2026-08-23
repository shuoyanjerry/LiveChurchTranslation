import Testing
import TranslationQualificationSupport

@Suite struct TranslationQualificationHardeningTests {
    @Test func rejectsNonPronounAndUnevidencedPronounSourceMutations() throws {
        let values = try fixtureValues()
        for source in ["他不这里。", "她在这里。"] {
            let changed = SyntheticTranslationAttemptCopy.make(
                values.attempt,
                segment: values.segment,
                translationSource: source
            )
            #expect(throws: TranslationQualificationError.self) {
                _ = try rebuild(values, replacing: changed)
            }
        }
    }

    @Test func permitsEvidenceBoundTaMutationButHardFailsWrongGoldenGuidance() throws {
        let values = try fixtureValues()
        let occurrence = try #require(values.segment.pronounOccurrences.first)
        let result = TranslationQualificationPronounResult(
            occurrenceID: occurrence.id,
            expectedGuidance: occurrence.expectedGuidance,
            actualGuidance: "verifiedFemale",
            guidanceStatus: .fail,
            englishToken: nil,
            englishClass: "feminine",
            englishPolicyStatus: .fail
        )
        let changed = SyntheticTranslationAttemptCopy.make(
            values.attempt,
            segment: values.segment,
            translationSource: "她在这里。",
            pronounResults: [result]
        )

        let report = try rebuild(values, replacing: changed)
        #expect(!TranslationQualificationReleaseGate.evaluate(report).passesHardGates)
    }

    @Test func hardGateSeparatesMachineFailuresFromHumanReview() throws {
        let values = try fixtureValues()
        let baseline = try rebuild(values, replacing: values.attempt)
        let baselineGate = TranslationQualificationReleaseGate.evaluate(baseline)
        #expect(baselineGate.passesHardGates)
        #expect(baselineGate.humanReviewRequiredCount > 0)
        #expect(!baselineGate.passesReleaseReadyGates)

        let failedTerm = TranslationQualificationTermResult(
            source: "这里",
            preferredTarget: "synthetic term",
            acceptedTargets: [],
            required: true,
            status: .fail
        )
        let changed = SyntheticTranslationAttemptCopy.make(
            values.attempt,
            segment: values.segment,
            glossaryTerms: [failedTerm]
        )
        let report = try rebuild(values, replacing: changed)
        let result = TranslationQualificationReleaseGate.evaluate(report)
        #expect(!result.passesHardGates)
        #expect(throws: TranslationQualificationError.self) {
            try TranslationQualificationReleaseGate.requireHardGates(report)
        }
    }

    @Test func preferredTermFailureIsDiagnosticNotReleaseFailure() throws {
        let values = try fixtureValues()
        let preferred = TranslationQualificationTermResult(
            source: "这里",
            preferredTarget: "synthetic term",
            acceptedTargets: [],
            required: false,
            status: .fail
        )
        let changed = SyntheticTranslationAttemptCopy.make(
            values.attempt,
            segment: values.segment,
            glossaryTerms: [preferred]
        )

        let report = try rebuild(values, replacing: changed)
        #expect(TranslationQualificationReleaseGate.evaluate(report).passesHardGates)
    }

    @Test func providerFailureAlwaysFailsReleaseGateAndStaysInDenominator() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let report = try SyntheticTranslationReportFactory.build(
            corpus: fixture.load(),
            failingIndex: 10
        )
        let result = TranslationQualificationReleaseGate.evaluate(report)

        #expect(result.providerFailureCount == 1)
        #expect(!result.passesHardGates)
        #expect(report.aggregate.attemptCount == 100)
    }

    private func fixtureValues() throws -> FixtureValues {
        let fixture = try SyntheticTranslationWorkspace()
        let corpus = try fixture.load()
        let report = try SyntheticTranslationReportFactory.build(corpus: corpus)
        return FixtureValues(
            corpus: corpus,
            report: report,
            segment: corpus.manifest.segments[1],
            attempt: report.attempts[1]
        )
    }

    private func rebuild(
        _ values: FixtureValues,
        replacing attempt: TranslationQualificationAttempt
    ) throws -> TranslationQualificationReport {
        var attempts = values.report.attempts
        attempts[1] = attempt
        return try TranslationQualificationReportBuilder.build(
            generatedAt: values.report.generatedAt,
            corpus: values.corpus,
            provider: values.report.provider,
            environment: values.report.environment,
            attempts: attempts
        )
    }
}

private struct FixtureValues {
    let corpus: TranslationQualificationCorpus
    let report: TranslationQualificationReport
    let segment: TranslationQualificationSegment
    let attempt: TranslationQualificationAttempt
}

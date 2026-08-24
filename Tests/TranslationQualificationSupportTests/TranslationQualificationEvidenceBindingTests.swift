import Testing
import TranslationQualificationSupport

@Suite struct QualificationEvidenceBindingTests {
    @Test func rejectsOmittedGlossaryPreservationAndPronounEvidence() throws {
        let values = try evidenceValues()
        let attempts = [
            SyntheticTranslationAttemptCopy.make(
                values.attempt,
                segment: values.segment,
                glossaryTerms: []
            ),
            SyntheticTranslationAttemptCopy.make(
                values.attempt,
                segment: values.segment,
                preservationChecks: []
            ),
            SyntheticTranslationAttemptCopy.make(
                values.attempt,
                segment: values.segment,
                pronounResults: []
            ),
        ]

        for attempt in attempts {
            #expect(throws: TranslationQualificationError.self) {
                _ = try rebuildEvidence(values, replacing: attempt)
            }
        }
    }

    @Test func rejectsFabricatedGlossaryPreservationAndPronounPasses() throws {
        let values = try evidenceValues()
        let attempts = [
            try fakeGlossaryAttempt(values),
            fakePreservationAttempt(values),
            try fakePronounAttempt(values),
        ]

        for attempt in attempts {
            #expect(throws: TranslationQualificationError.self) {
                _ = try rebuildEvidence(values, replacing: attempt)
            }
        }
    }

    @Test func traceIntegrityRequiresOnePayloadlessStructuredCheck() throws {
        let values = try evidenceValues()
        let checks = values.attempt.preservationChecks
        let trace = try #require(checks.last)
        let invalidChecks = [
            Array(checks.dropLast()),
            checks + [trace],
            Array(checks.dropLast()) + [
                TranslationQualificationCheck(
                    kind: "pronounTraceIntegrity",
                    status: .pass,
                    expected: ["raw-detail"]
                )
            ],
            Array(checks.dropLast()) + [
                TranslationQualificationCheck(
                    kind: "pronounTraceIntegrity",
                    status: .notApplicable
                )
            ],
        ]

        for preservationChecks in invalidChecks {
            let attempt = SyntheticTranslationAttemptCopy.make(
                values.attempt,
                segment: values.segment,
                preservationChecks: preservationChecks
            )
            #expect(throws: TranslationQualificationError.self) {
                _ = try rebuildEvidence(values, replacing: attempt)
            }
        }
    }

    @Test func traceIntegrityCanBeNotApplicableWithoutSingularPronouns() throws {
        let values = try evidenceValues()
        let heading = values.corpus.manifest.segments[0]
        let baseline = values.report.attempts[0]
        let checks =
            baseline.preservationChecks.dropLast() + [
                TranslationQualificationCheck(
                    kind: "pronounTraceIntegrity",
                    status: .notApplicable
                )
            ]
        let attempt = SyntheticTranslationAttemptCopy.make(
            baseline,
            segment: heading,
            preservationChecks: Array(checks)
        )

        #expect(throws: Never.self) {
            _ = try rebuildEvidence(values, replacing: attempt, at: 0)
        }
    }
}

private func fakeGlossaryAttempt(
    _ values: TranslationEvidenceValues
) throws -> TranslationQualificationAttempt {
    let term = try #require(values.attempt.glossaryTerms.first)
    let fake = TranslationQualificationTermResult(
        source: term.source,
        preferredTarget: "absent-target",
        acceptedTargets: [],
        required: true,
        status: .pass
    )
    return SyntheticTranslationAttemptCopy.make(
        values.attempt,
        segment: values.segment,
        glossaryTerms: [fake]
    )
}

private func fakePreservationAttempt(
    _ values: TranslationEvidenceValues
) -> TranslationQualificationAttempt {
    let checks = values.attempt.preservationChecks.map { check in
        check.kind == "numbers"
            ? TranslationQualificationCheck(kind: check.kind, status: .pass)
            : check
    }
    return SyntheticTranslationAttemptCopy.make(
        values.attempt,
        segment: values.segment,
        preservationChecks: checks
    )
}

private func fakePronounAttempt(
    _ values: TranslationEvidenceValues
) throws -> TranslationQualificationAttempt {
    let result = try #require(values.attempt.pronounResults.first)
    let fake = TranslationQualificationPronounResult(
        occurrenceID: result.occurrenceID,
        expectedGuidance: result.expectedGuidance,
        actualGuidance: result.actualGuidance,
        guidanceStatus: .pass,
        englishToken: nil,
        englishClass: "masculine",
        englishPolicyStatus: .pass
    )
    return SyntheticTranslationAttemptCopy.make(
        values.attempt,
        segment: values.segment,
        pronounResults: [fake]
    )
}

private struct TranslationEvidenceValues {
    let corpus: TranslationQualificationCorpus
    let report: TranslationQualificationReport
    let segment: TranslationQualificationSegment
    let attempt: TranslationQualificationAttempt
}

private func evidenceValues() throws -> TranslationEvidenceValues {
    let fixture = try SyntheticTranslationWorkspace()
    let corpus = try fixture.load()
    let report = try SyntheticTranslationReportFactory.build(corpus: corpus)
    return TranslationEvidenceValues(
        corpus: corpus,
        report: report,
        segment: corpus.manifest.segments[1],
        attempt: report.attempts[1]
    )
}

private func rebuildEvidence(
    _ values: TranslationEvidenceValues,
    replacing attempt: TranslationQualificationAttempt,
    at index: Int = 1
) throws -> TranslationQualificationReport {
    var attempts = values.report.attempts
    attempts[index] = attempt
    return try TranslationQualificationReportBuilder.build(
        generatedAt: values.report.generatedAt,
        corpus: values.corpus,
        provider: values.report.provider,
        environment: values.report.environment,
        attempts: attempts
    )
}

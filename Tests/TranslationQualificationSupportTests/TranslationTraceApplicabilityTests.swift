import Testing
@testable import TranslationQualificationSupport

@Suite struct TranslationTraceApplicabilityTests {
    @Test func rejectsForgedPassWhenNoSingularPronounExists() throws {
        let values = try evidenceValues()
        let heading = values.corpus.manifest.segments[0]
        let attempt = traceAttempt(
            values.report.attempts[0],
            segment: heading,
            status: .pass
        )

        #expect(throws: TranslationQualificationError.self) {
            _ = try rebuildEvidence(values, replacing: attempt, at: 0)
        }
    }

    @Test func acceptsNotApplicableForEveryNonSingularTokenCombination() throws {
        for tokenClasses in nonSingularTokenCases {
            let segment = try SyntheticTraceEvidenceFixture.segment(tokenClasses: tokenClasses)
            let attempt = SyntheticTraceEvidenceFixture.attempt(
                segment: segment,
                traceStatus: .notApplicable
            )

            #expect(throws: Never.self) {
                _ = try TranslationComputedEvidenceValidator.validate(
                    attempt: attempt,
                    segment: segment
                )
            }
        }
    }

    @Test func rejectsNotApplicableWhenAnySingularPronounExists() throws {
        let segment = try SyntheticTraceEvidenceFixture.segment(
            tokenClasses: [.singularPronoun, .pluralPronoun]
        )
        let attempt = SyntheticTraceEvidenceFixture.attempt(
            segment: segment,
            traceStatus: .notApplicable
        )

        #expect(throws: TranslationQualificationError.self) {
            _ = try TranslationComputedEvidenceValidator.validate(
                attempt: attempt,
                segment: segment
            )
        }
    }

    @Test func rejectsPassForSingularPronounWithoutHypothesis() throws {
        let segment = try SyntheticTraceEvidenceFixture.segment(
            tokenClasses: [.singularPronoun]
        )
        let attempt = SyntheticTraceEvidenceFixture.attempt(
            segment: segment,
            status: .failure,
            traceStatus: .pass
        )

        #expect(throws: TranslationQualificationError.self) {
            _ = try TranslationComputedEvidenceValidator.validate(
                attempt: attempt,
                segment: segment
            )
        }
    }

    @Test func inapplicableTraceFailureRemainsAReleaseGateFailure() throws {
        let values = try evidenceValues()
        let heading = values.corpus.manifest.segments[0]
        let attempt = traceAttempt(
            values.report.attempts[0],
            segment: heading,
            status: .fail
        )
        let report = try rebuildEvidence(values, replacing: attempt, at: 0)
        let result = TranslationQualificationReleaseGate.evaluate(report)

        #expect(result.hardCheckFailureCount == 1)
        #expect(result.releaseCheckFailureCount == 1)
        #expect(!result.passesHardGates)
        #expect(!result.passesReleaseReadyGates)
    }
}

private let nonSingularTokenCases: [[TranslationPronounTokenClass]] = [
    [.pluralPronoun],
    [.lexicalOtherPeople],
    [.pluralPronoun, .lexicalOtherPeople],
]

private func traceAttempt(
    _ baseline: TranslationQualificationAttempt,
    segment: TranslationQualificationSegment,
    status: TranslationQualificationCheckStatus
) -> TranslationQualificationAttempt {
    let checks =
        Array(baseline.preservationChecks.dropLast()) + [
            TranslationQualificationCheck(
                kind: "pronounTraceIntegrity",
                status: status
            )
        ]
    return SyntheticTranslationAttemptCopy.make(
        baseline,
        segment: segment,
        preservationChecks: checks
    )
}

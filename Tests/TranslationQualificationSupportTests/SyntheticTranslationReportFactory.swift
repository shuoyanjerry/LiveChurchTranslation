import TranslationQualificationSupport

enum SyntheticTranslationReportFactory {
    static func build(
        corpus: TranslationQualificationCorpus,
        failingIndex: Int? = nil,
        invalidContextIndex: Int? = nil,
        includeExecutionProvenance: Bool = true
    ) throws -> TranslationQualificationReport {
        var persisted: [String: [String]] = [:]
        var attempts: [TranslationQualificationAttempt] = []
        for (index, segment) in corpus.manifest.segments.enumerated() {
            let fails = index == failingIndex
            var context = Array(persisted[segment.sourceID, default: []].suffix(2))
            if index == invalidContextIndex { context = ["invalid-context"] }
            let hypothesis = fails ? nil : expectedHypothesis(segment)
            attempts.append(
                attempt(
                    segment,
                    context: context,
                    hypothesis: hypothesis,
                    fails: fails
                )
            )
            if !fails { persisted[segment.sourceID, default: []].append(segment.id) }
        }
        return try TranslationQualificationReportBuilder.build(
            generatedAt: "2026-08-22T12:00:00Z",
            corpus: corpus,
            provider: provider,
            environment: environment,
            executionProvenance: includeExecutionProvenance ? try provenance(corpus) : nil,
            attempts: attempts
        )
    }

    static func releaseExpectation(
        corpus: TranslationQualificationCorpus
    ) throws -> TranslationReleaseExpectation {
        let attempts = try build(corpus: corpus).attempts
        return try TranslationReleaseExpectation(
            trustedExecutionProvenance: provenance(corpus),
            corpus: corpus,
            provider: provider,
            environment: environment,
            attempts: attempts
        )
    }

    private static let provider = TranslationQualificationProvider(
        identifier: "synthetic.provider",
        modelRevision: "synthetic-v1",
        modelSHA256: String(repeating: "a", count: 64),
        runtimeRevision: "synthetic-runtime-v1",
        runtimeSHA256: String(repeating: "b", count: 64),
        settings: [
            "buildConfiguration": "release",
            "discourseContextEntries": "2",
            "qualificationGlossaryCatalogPolicy": "synthetic-exact-v1",
            "qualificationGlossaryCatalogSHA256": String(repeating: "9", count: 64),
            "threads": "1",
            "translationContextEntries": "2",
        ]
    )

    private static let environment = TranslationQualificationEnvironment(
        hardware: "synthetic-hardware",
        operatingSystem: "synthetic-os",
        repositoryRevision: "synthetic-revision",
        backgroundLoad: "controlled"
    )
}

extension SyntheticTranslationReportFactory {
    private static func attempt(
        _ segment: TranslationQualificationSegment,
        context: [String],
        hypothesis: String?,
        fails: Bool
    ) -> TranslationQualificationAttempt {
        let guidance = segment.pronounOccurrences.map {
            TranslationGuidanceObservation(
                occurrenceID: $0.id,
                resolution: "unresolvedSpokenMandarin"
            )
        }
        let preservation = TranslationPreservationEvaluator.evaluate(
            segment: segment,
            hypothesis: hypothesis,
            terms: termExpectations(segment)
        )
        return TranslationQualificationAttempt(
            segment: segment,
            status: fails ? .failure : .success,
            hypothesisEnglish: hypothesis,
            translationSourceText: segment.observedASRAmbiguousChinese,
            contextSegmentIDs: context,
            strictRetryUsed: false,
            completionAttemptCount: 1,
            completionOutcomes: [fails ? "initial.transportFailed" : "initial.accepted"],
            latencySeconds: Double(segment.sequence) / 100,
            failureCode: fails ? "synthetic.transport-failure" : nil,
            glossaryTerms: preservation.terms,
            preservationChecks: preservation.checks + [traceCheck(segment, hypothesis: hypothesis)],
            pronounResults: TranslationPronounEvaluator.evaluate(
                occurrences: segment.pronounOccurrences,
                guidance: guidance,
                realizations: segment.pronounOccurrences.compactMap(realization),
                hypothesisAvailable: hypothesis != nil
            )
        )
    }

    private static func termExpectations(
        _ segment: TranslationQualificationSegment
    ) -> [TranslationQualificationTermExpectation] {
        segment.theologyTerms.map {
            TranslationQualificationTermExpectation(
                source: $0,
                preferredTarget: "here",
                required: true
            )
        }
    }

    private static func traceCheck(
        _ segment: TranslationQualificationSegment,
        hypothesis: String?
    ) -> TranslationQualificationCheck {
        let status: TranslationQualificationCheckStatus =
            hypothesis != nil
                && segment.pronounOccurrences.contains { $0.tokenClass == .singularPronoun }
            ? .pass : .notApplicable
        return TranslationQualificationCheck(
            kind: "pronounTraceIntegrity",
            status: status
        )
    }

    private static func realization(
        _ occurrence: TranslationPronounOccurrence
    ) -> TranslationPronounRealizationObservation? {
        guard occurrence.tokenClass == .singularPronoun else { return nil }
        return TranslationPronounRealizationObservation(
            occurrenceID: occurrence.id,
            resolution: "unresolvedSpokenMandarin",
            realizationClass: "singularThey"
        )
    }

    private static func expectedHypothesis(
        _ segment: TranslationQualificationSegment
    ) -> String {
        segment.pronounOccurrences.isEmpty ? "Synthetic heading" : "They are here."
    }

    private static func provenance(
        _ corpus: TranslationQualificationCorpus
    ) throws -> TranslationExecutionProvenance {
        TranslationExecutionProvenance(
            buildConfiguration: "release",
            sourceBundle: bundle("c"),
            testExecutable: artifact("d"),
            model: artifact("a"),
            helper: artifact("b"),
            runtimeBundle: bundle("e"),
            configurationSHA256: try TranslationConfigurationHasher.hash(
                settings: provider.settings
            ),
            manifestSHA256: corpus.manifestSHA256,
            corpusSchemaSHA256: corpus.schemaSHA256
        )
    }

}

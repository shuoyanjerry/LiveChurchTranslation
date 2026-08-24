import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct HumanReviewEligibilityTests {
    @Test func semanticScoringEligibilityAloneDoesNotCreateReviewAxes() throws {
        let fixture = try SyntheticTranslationWorkspace(requiresHumanReview: false)
        let data = try Data(contentsOf: fixture.manifestURL)
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var segments = try #require(object["segments"] as? [[String: Any]])
        var qualification = try #require(segments[1]["qualification"] as? [String: Any])
        qualification["semanticScoringEligible"] = true
        segments[1]["qualification"] = qualification
        object["segments"] = segments
        let changed = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        try changed.write(to: fixture.manifestURL)
        let corpus = try TranslationQualificationCorpusLoader.load(
            manifestURL: fixture.manifestURL,
            workspaceRoot: fixture.root,
            expectedManifestSHA256: TranslationQualificationSHA256.hash(data: changed),
            expectedSchemaSHA256: fixture.schemaSHA256
        )
        let report = try SyntheticTranslationReportFactory.build(corpus: corpus)
        let expectation = try SyntheticTranslationReportFactory.releaseExpectation(corpus: corpus)
        let itemIDs = try TranslationHumanReviewEvidence.requiredReviewItemIDs(
            report: report,
            expectation: expectation
        )
        let rawGate = TranslationQualificationReleaseGate.evaluate(
            report,
            expectation: expectation
        )

        #expect(report.attempts[1].semanticReviewEligible)
        #expect(!corpus.manifest.segments[1].qualification.requiresHumanSemanticReview)
        #expect(itemIDs.count == rawGate.humanReviewRequiredCount + rawGate.backendReviewIssueCount)
    }

    @Test func builderRejectsAttemptSemanticEligibilityDrift() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let corpus = try fixture.load()
        let report = try SyntheticTranslationReportFactory.build(corpus: corpus)
        var object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(report.attempts[1]))
                as? [String: Any]
        )
        object["semanticReviewEligible"] = false
        let changed = try JSONDecoder().decode(
            TranslationQualificationAttempt.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        var attempts = report.attempts
        attempts[1] = changed

        #expect(throws: TranslationQualificationError.self) {
            _ = try TranslationQualificationReportBuilder.build(
                generatedAt: report.generatedAt,
                corpus: corpus,
                provider: report.provider,
                environment: report.environment,
                executionProvenance: report.executionProvenance,
                attempts: attempts
            )
        }
    }
}

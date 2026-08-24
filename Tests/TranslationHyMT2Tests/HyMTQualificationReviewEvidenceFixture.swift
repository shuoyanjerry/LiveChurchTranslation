import CryptoKit
import Foundation
import Testing
import TranslationQualificationSupport

extension HyMTQualificationReviewEvidenceTests {
    func semanticReport() throws -> (
        report: TranslationQualificationReport,
        expectation: TranslationReleaseExpectation
    ) {
        var manifest = HyMTPostflightTestFixture.manifest
        var segment = try #require((manifest["segments"] as? [[String: Any]])?.first)
        segment["unitKind"] = "content"
        segment["qualification"] = [
            "semanticScoringEligible": true, "exactStringScoringEligible": false,
            "asrCEREligible": false, "requiresHumanSemanticReview": true,
        ]
        manifest["segments"] = [segment]
        manifest["summary"] = summary
        let decoded = try TranslationQualificationManifestDecoder.decode(
            JSONSerialization.data(withJSONObject: manifest)
        )
        let fixture = try HyMTPostflightTestFixture.make()
        let corpus = TranslationQualificationCorpus(
            manifest: decoded,
            manifestSHA256: fixture.provenance.manifestSHA256,
            schemaSHA256: fixture.provenance.corpusSchemaSHA256
        )
        let attempt = try successAttempt(try #require(decoded.segments.first))
        let report = try TranslationQualificationReportBuilder.build(
            generatedAt: "2026-08-22T12:00:00Z",
            corpus: corpus,
            provider: fixture.report.provider,
            environment: fixture.report.environment,
            executionProvenance: fixture.provenance,
            attempts: [attempt]
        )
        let expectation = try TranslationReleaseExpectation(
            trustedExecutionProvenance: fixture.provenance,
            corpus: corpus,
            provider: report.provider,
            environment: report.environment,
            attempts: report.attempts
        )
        return (report, expectation)
    }

    func successAttempt(
        _ segment: TranslationQualificationSegment
    ) throws -> TranslationQualificationAttempt {
        let preservation = TranslationPreservationEvaluator.evaluate(
            segment: segment,
            hypothesis: "Synthetic title",
            terms: []
        )
        return TranslationQualificationAttempt(
            segment: segment,
            status: .success,
            hypothesisEnglish: "Synthetic title",
            translationSourceText: segment.observedASRAmbiguousChinese,
            contextSegmentIDs: [],
            strictRetryUsed: false,
            completionAttemptCount: 1,
            completionOutcomes: ["initial.accepted"],
            latencySeconds: 0.1,
            failureCode: nil,
            glossaryTerms: preservation.terms,
            preservationChecks: preservation.checks + [
                TranslationQualificationCheck(
                    kind: "pronounTraceIntegrity",
                    status: .notApplicable
                )
            ],
            pronounResults: []
        )
    }

    func reviewers() throws -> [TranslationHumanReviewerIdentity] {
        try [
            reviewer(seed: String(repeating: "01", count: 32), role: .bilingualTheology),
            reviewer(seed: String(repeating: "02", count: 32), role: .independentLanguage),
        ]
    }

    func reviewer(
        seed: String,
        role: TranslationHumanReviewerRole
    ) throws -> TranslationHumanReviewerIdentity {
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation: try data(hex: seed))
        let publicKey = key.publicKey.rawRepresentation.base64EncodedString()
        let reviewerID = try TranslationHumanReviewEvidence.reviewerID(
            forPublicKeyBase64: publicKey
        )
        return TranslationHumanReviewerIdentity(
            reviewerID: reviewerID,
            reviewerRole: role,
            qualificationDeclarationSHA256: sha(role == .bilingualTheology ? "1" : "2"),
            independenceDeclarationSHA256: sha(role == .bilingualTheology ? "3" : "4"),
            publicKeyBase64: publicKey
        )
    }

    var summary: [String: Any] {
        [
            "sourceCount": 0, "segmentPairCount": 1, "contentPairCount": 1,
            "headingOrTitlePairCount": 0, "sourcePairCounts": [], "featureTagCounts": [],
            "taGlyphOccurrenceCount": 0, "pronounGuidanceCounts": [],
            "grnCandidateCount": 0, "hesedExcludedCount": 0,
        ]
    }

    var semanticAxes: Set<String> {
        ["fidelity", "completeness", "naturalness", "theology", "properNames"]
    }

    func sha(_ character: Character) -> String {
        String(repeating: character, count: 64)
    }

    func data(hex: String) throws -> Data {
        guard hex.count.isMultiple(of: 2) else { throw ReviewFixtureError.invalidHex }
        var value = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let end = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<end], radix: 16) else {
                throw ReviewFixtureError.invalidHex
            }
            value.append(byte)
            index = end
        }
        return value
    }
}

private enum ReviewFixtureError: Error {
    case invalidHex
}

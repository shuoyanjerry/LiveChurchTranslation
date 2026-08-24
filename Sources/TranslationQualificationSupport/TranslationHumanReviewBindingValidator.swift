enum HumanReviewBindingValidator {
    static func failureCount(
        report: TranslationQualificationReport,
        expectation: TranslationReleaseExpectation,
        settlement: TranslationHumanReviewSettlement,
        requirements: [TranslationHumanReviewRequirement]
    ) -> Int {
        var failures = metadataFailures(report, expectation: expectation, settlement: settlement)
        failures += reviewerIdentityFailures(
            settlement.submissions,
            trustedReviewers: expectation.trustedHumanReviewers
        )
        let expectedItemIDs = Set(requirements.map(\.itemID))
        let context = settlement.signatureContext
        failures += settlement.submissions.reduce(0) { count, submission in
            count
                + submissionFailures(
                    submission,
                    context: context,
                    expectedItemIDs: expectedItemIDs
                )
        }
        return failures
    }

    private static func metadataFailures(
        _ report: TranslationQualificationReport,
        expectation: TranslationReleaseExpectation,
        settlement: TranslationHumanReviewSettlement
    ) -> Int {
        guard TranslationProvenanceValidator.isReleaseBound(report, expectation: expectation),
            settlement.schemaVersion == TranslationHumanReviewSettlement.currentSchemaVersion,
            settlement.policyRevision == TranslationHumanReviewEvidence.currentPolicyRevision,
            settlement.reportBinding == (try? TranslationHumanReviewEvidence.reportBinding(for: report)),
            settlement.reportBinding.manifestSHA256 == expectation.corpus.manifestSHA256,
            settlement.reportBinding.attemptIdentitySHA256 == expectation.attemptIdentitySHA256,
            settlement.reviewPacketSHA256 == expectation.trustedHumanReviewPacketSHA256,
            settlement.reviewerRegistrySHA256
                == expectation.trustedHumanReviewerRegistrySHA256,
            settlement.submissions.count == 2
        else { return 1 }
        return 0
    }

    private static func reviewerIdentityFailures(
        _ submissions: [TranslationHumanReviewSubmission],
        trustedReviewers: [TranslationHumanReviewerIdentity]
    ) -> Int {
        guard submissions.count == 2,
            HumanReviewSignatureValidator.validTrustedReviewers(trustedReviewers)
        else { return 1 }
        let reviewers = Set(submissions.map(\.reviewer.reviewerID))
        let keys = Set(submissions.map(\.reviewer.publicKeyBase64))
        let roles = Set(submissions.map(\.reviewer.reviewerRole))
        let qualifications = Set(submissions.map(\.reviewer.qualificationDeclarationSHA256))
        let independence = Set(submissions.map(\.reviewer.independenceDeclarationSHA256))
        guard reviewers.count == 2, keys.count == 2, roles.count == 2,
            qualifications.count == 2, independence.count == 2,
            submissions.map(\.reviewer).allSatisfy(HumanReviewSignatureValidator.validIdentity),
            submissions.map(\.reviewer).allSatisfy(trustedReviewers.contains)
        else { return 1 }
        return 0
    }

    private static func submissionFailures(
        _ submission: TranslationHumanReviewSubmission,
        context: TranslationHumanReviewSignatureContext,
        expectedItemIDs: Set<String>
    ) -> Int {
        let itemIDs = submission.reviews.map(\.itemID)
        guard Set(itemIDs).count == itemIDs.count, Set(itemIDs) == expectedItemIDs,
            itemIDs.allSatisfy(HumanReviewSignatureValidator.validItemID),
            HumanReviewSignatureValidator.validSignature(
                submission,
                context: context
            )
        else { return 1 }
        return 0
    }
}

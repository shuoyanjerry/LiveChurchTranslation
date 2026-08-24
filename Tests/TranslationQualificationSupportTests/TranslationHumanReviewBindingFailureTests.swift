import CryptoKit
import Testing
import TranslationQualificationSupport

@Suite struct HumanReviewBindingFailureTests {
    @Test func missingExtraAndDuplicateReviewKeysFailClosed() throws {
        let values = try releaseValues()
        let reviews = try SyntheticHumanReviewSettlementFactory.reviews(
            report: values.report,
            expectation: values.expectation
        )
        let first = try #require(reviews.first)
        let variants = try coverageVariants(
            values,
            reviews: reviews,
            duplicate: first,
            unknownItemID: zeros
        )

        for settlement in variants {
            let result = try evaluateHumanReview(values, settlement)
            #expect(result.resolvedHumanReviewCount == 0)
            #expect(result.outstandingHumanReviewCount == reviews.count)
            #expect(result.reviewBindingFailureCount > 0)
            #expect(!result.passesReleaseReadyGates)
        }
    }

    @Test func reviewerOrPublicKeyReuseFailsClosed() throws {
        let values = try releaseValues(requiresHumanReview: false)
        let sharedKey = Curve25519.Signing.PrivateKey()
        let variants = try [
            SyntheticHumanReviewSettlementFactory.make(
                report: values.report,
                expectation: values.expectation,
                firstReviewerID: "reviewer-shared-01",
                secondReviewerID: "reviewer-shared-01"
            ),
            SyntheticHumanReviewSettlementFactory.make(
                report: values.report,
                expectation: values.expectation,
                firstKey: sharedKey,
                secondKey: sharedKey
            ),
            SyntheticHumanReviewSettlementFactory.make(
                report: values.report,
                expectation: values.expectation,
                firstRole: .bilingualTheology,
                secondRole: .bilingualTheology
            ),
        ]

        for settlement in variants {
            let result = try evaluateHumanReview(values, settlement)
            #expect(result.reviewBindingFailureCount > 0)
            #expect(!result.passesReleaseReadyGates)
        }
    }

    @Test func selfAssertedUntrustedReviewerKeyFailsClosed() throws {
        let values = try releaseValues(requiresHumanReview: false)
        let settlement = try SyntheticHumanReviewSettlementFactory.make(
            report: values.report,
            expectation: values.expectation,
            firstKey: Curve25519.Signing.PrivateKey()
        )

        let result = try evaluateHumanReview(values, settlement)
        #expect(result.reviewBindingFailureCount > 0)
        #expect(!result.passesReleaseReadyGates)
    }

    @Test func reviewerIdentityMustBeBoundedASCIIAndNonIdentifying() throws {
        let values = try releaseValues(requiresHumanReview: false)
        let invalidIDs = [
            "short", "alice@example.com", "Alice Smith slot", "AliceSmithPerson1",
            "reviewer-AliceSmith-01",
            "审稿人伪名一二三四五六",
        ]

        for reviewerID in invalidIDs {
            let settlement = try SyntheticHumanReviewSettlementFactory.make(
                report: values.report,
                expectation: values.expectation,
                firstReviewerID: reviewerID
            )
            let result = try evaluateHumanReview(values, settlement)
            #expect(result.reviewBindingFailureCount > 0)
            #expect(!result.passesReleaseReadyGates)
        }
    }

}

func evaluateHumanReview(
    _ values: TranslationReleaseValues,
    _ settlement: TranslationHumanReviewSettlement
) throws -> TranslationQualificationGateResult {
    TranslationQualificationReleaseGate.evaluate(
        values.report,
        expectation: values.expectation,
        humanReviewSidecar: try SyntheticHumanReviewSettlementFactory.data(settlement)
    )
}

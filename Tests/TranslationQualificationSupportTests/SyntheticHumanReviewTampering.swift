import Foundation
import Testing
import TranslationQualificationSupport

let zeros = String(repeating: "0", count: 64)

func coverageVariants(
    _ values: TranslationReleaseValues,
    reviews: [TranslationHumanReviewItem],
    duplicate: TranslationHumanReviewItem,
    unknownItemID: String
) throws -> [TranslationHumanReviewSettlement] {
    try [
        SyntheticHumanReviewSettlementFactory.make(
            report: values.report,
            expectation: values.expectation,
            firstReviews: Array(reviews.dropLast())
        ),
        SyntheticHumanReviewSettlementFactory.make(
            report: values.report,
            expectation: values.expectation,
            firstReviews: reviews + [duplicate]
        ),
        SyntheticHumanReviewSettlementFactory.make(
            report: values.report,
            expectation: values.expectation,
            firstReviews: reviews + [
                TranslationHumanReviewItem(itemID: unknownItemID, verdict: .pass)
            ]
        ),
    ]
}

func copy(
    _ value: TranslationHumanReviewReportBinding,
    report: String? = nil,
    manifest: String? = nil,
    attempts: String? = nil
) -> TranslationHumanReviewReportBinding {
    TranslationHumanReviewReportBinding(
        reportSHA256: report ?? value.reportSHA256,
        manifestSHA256: manifest ?? value.manifestSHA256,
        attemptIdentitySHA256: attempts ?? value.attemptIdentitySHA256
    )
}

func copy(
    _ value: TranslationHumanReviewSettlement,
    reviewPacketSHA256: String? = nil,
    reviewerRegistrySHA256: String? = nil,
    submissions: [TranslationHumanReviewSubmission]? = nil
) -> TranslationHumanReviewSettlement {
    TranslationHumanReviewSettlement(
        policyRevision: value.policyRevision,
        reportBinding: value.reportBinding,
        reviewPacketSHA256: reviewPacketSHA256 ?? value.reviewPacketSHA256,
        reviewerRegistrySHA256: reviewerRegistrySHA256 ?? value.reviewerRegistrySHA256,
        submissions: submissions ?? value.submissions
    )
}

func corruptFirstSignature(
    _ value: TranslationHumanReviewSettlement
) throws -> TranslationHumanReviewSettlement {
    var submissions = value.submissions
    let first = try #require(submissions.first)
    submissions[0] = TranslationHumanReviewSubmission(
        reviewer: first.reviewer,
        reviews: first.reviews,
        signatureBase64: Data(repeating: 0, count: 64).base64EncodedString()
    )
    return copy(value, submissions: submissions)
}

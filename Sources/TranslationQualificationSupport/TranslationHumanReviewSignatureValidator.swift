import CryptoKit
import Foundation

enum HumanReviewSignatureValidator {
    static func validSignature(
        _ submission: TranslationHumanReviewSubmission,
        context: TranslationHumanReviewSignatureContext
    ) -> Bool {
        let reviewer = submission.reviewer
        guard let keyData = canonicalBase64(reviewer.publicKeyBase64), keyData.count == 32,
            let signature = canonicalBase64(submission.signatureBase64), signature.count == 64,
            let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData),
            let payload = try? TranslationHumanReviewEvidence.signingPayload(
                context: context,
                reviewer: reviewer,
                reviews: submission.reviews
            )
        else { return false }
        return publicKey.isValidSignature(signature, for: payload)
    }

    static func validIdentity(_ reviewer: TranslationHumanReviewerIdentity) -> Bool {
        reviewer.reviewerID
            == (try? TranslationHumanReviewEvidence.reviewerID(
                forPublicKeyBase64: reviewer.publicKeyBase64
            ))
            && validSHA(reviewer.qualificationDeclarationSHA256)
            && validSHA(reviewer.independenceDeclarationSHA256)
    }

    static func validTrustedReviewers(
        _ reviewers: [TranslationHumanReviewerIdentity]
    ) -> Bool {
        guard (2...128).contains(reviewers.count), reviewers.allSatisfy(validIdentity) else {
            return false
        }
        return Set(reviewers.map(\.reviewerID)).count == reviewers.count
            && Set(reviewers.map(\.publicKeyBase64)).count == reviewers.count
    }

    static func validItemID(_ value: String) -> Bool {
        validSHA(value)
    }

    private static func validSHA(_ value: String) -> Bool {
        guard value.utf8.count == 64, value.utf8.count == value.count else { return false }
        return value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }

    private static func canonicalBase64(_ value: String) -> Data? {
        guard let data = Data(base64Encoded: value), data.base64EncodedString() == value else {
            return nil
        }
        return data
    }
}

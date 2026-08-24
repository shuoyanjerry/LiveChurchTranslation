import Foundation
import TranslationQualificationSupport

struct HyMTAdjudicationConfiguration {
    static let environmentFlag = "TRANSLATION_QUALIFICATION_ADJUDICATE"

    let qualification: HyMTQualificationConfiguration
    let signedFreezeURL: URL
    let reviewerRegistryURL: URL
    let humanReviewSidecarURL: URL

    static func load(_ environment: [String: String]) throws -> Self? {
        guard environment[environmentFlag] == "1" else { return nil }
        guard let qualification = try HyMTQualificationConfiguration.load(environment) else {
            throw invalid("adjudication qualification environment is incomplete")
        }
        return Self(
            qualification: qualification,
            signedFreezeURL: try url(
                "BILINGUAL_TRANSLATION_FREEZE_ATTESTATION",
                environment
            ),
            reviewerRegistryURL: try url(
                "BILINGUAL_TRANSLATION_REVIEWER_REGISTRY",
                environment
            ),
            humanReviewSidecarURL: try url(
                "BILINGUAL_TRANSLATION_HUMAN_REVIEW_SIDECAR",
                environment
            )
        )
    }

    private static func url(
        _ key: String,
        _ environment: [String: String]
    ) throws -> URL {
        guard let value = environment[key], value.first == "/" else {
            throw invalid("adjudication path \(key) must be absolute")
        }
        return URL(fileURLWithPath: value, isDirectory: false)
    }

    private static func invalid(_ message: String) -> TranslationQualificationError {
        .invalidReport(message)
    }
}

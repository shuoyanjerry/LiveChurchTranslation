import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct HyMTAdjudicationConfigurationTests {
    @Test func absentOptInDoesNotRequestAdjudication() throws {
        #expect(try HyMTAdjudicationConfiguration.load([:]) == nil)
    }

    @Test func optInWithoutSignedFreezeRegistryAndSidecarFailsClosed() {
        var environment = baseEnvironment()
        environment[HyMTAdjudicationConfiguration.environmentFlag] = "1"
        #expect(throws: TranslationQualificationError.self) {
            _ = try HyMTAdjudicationConfiguration.load(environment)
        }
    }

    @Test func acceptsOnlyCompleteExplicitSignedInputs() throws {
        var environment = baseEnvironment()
        environment[HyMTAdjudicationConfiguration.environmentFlag] = "1"
        environment["BILINGUAL_TRANSLATION_FREEZE_ATTESTATION"] = "/private/freeze.json"
        environment["BILINGUAL_TRANSLATION_REVIEWER_REGISTRY"] = "/private/registry.json"
        environment["BILINGUAL_TRANSLATION_HUMAN_REVIEW_SIDECAR"] = "/private/reviews.json"

        let value = try HyMTAdjudicationConfiguration.load(environment)
        let loaded = try #require(value)
        #expect(loaded.signedFreezeURL.path == "/private/freeze.json")
        #expect(loaded.reviewerRegistryURL.path == "/private/registry.json")
        #expect(loaded.humanReviewSidecarURL.path == "/private/reviews.json")
    }

    private func baseEnvironment() -> [String: String] {
        [
            "HYMT_MODEL_DIR": "/private/model",
            "HYMT_LLAMA_SERVER": "/private/helper",
            "BILINGUAL_TRANSLATION_MANIFEST": "/private/manifest.json",
            "BILINGUAL_TRANSLATION_REPORT": "report.json",
            "TRANSLATION_QUALIFICATION_SOURCE_BUNDLE_SHA256": sha("a"),
            "TRANSLATION_QUALIFICATION_TEST_EXECUTABLE_SHA256": sha("b"),
        ]
    }

    private func sha(_ character: Character) -> String {
        String(repeating: character, count: 64)
    }
}

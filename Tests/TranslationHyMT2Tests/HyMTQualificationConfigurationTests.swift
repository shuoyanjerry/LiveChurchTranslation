import Foundation
import Testing
import TranslationQualificationSupport

@Suite struct HyMTQualificationConfigurationTests {
    @Test func absentEnvironmentDoesNotRequestQualification() throws {
        #expect(!HyMTQualificationConfiguration.isRequested([:]))
        #expect(try HyMTQualificationConfiguration.load([:]) == nil)
    }

    @Test func partialEnvironmentFailsClosed() {
        let environment = ["HYMT_MODEL_DIR": "/private/model"]

        #expect(HyMTQualificationConfiguration.isRequested(environment))
        #expect(throws: TranslationQualificationError.self) {
            _ = try HyMTQualificationConfiguration.load(environment)
        }
    }

    @Test func rejectsReportPathInsteadOfFilename() {
        var environment = completeEnvironment()
        environment["BILINGUAL_TRANSLATION_REPORT"] = "../report.json"

        #expect(throws: TranslationQualificationError.self) {
            _ = try HyMTQualificationConfiguration.load(environment)
        }
    }

    @Test func reportsValuesFromActualProviderConfiguration() throws {
        let loaded = try HyMTQualificationConfiguration.load(completeEnvironment())
        let configuration = try #require(loaded)
        let provider = configuration.providerConfiguration

        #expect(configuration.providerSettings["contextSize"] == String(provider.contextSize))
        #expect(configuration.providerSettings["threadCount"] == String(provider.threadCount))
        #expect(configuration.providerSettings["temperature"] == "0.0")
        #expect(
            configuration.providerSettings["qualificationGlossaryCatalogSHA256"]
                == HyMTQualificationGlossary.catalogSHA256
        )
        #expect(
            configuration.providerSettings["qualificationGlossaryCatalogPolicy"]
                == HyMTQualificationGlossary.theologyPolicyID
        )
        #expect(configuration.reportFilename == "report.json")
    }

    private func completeEnvironment() -> [String: String] {
        [
            "HYMT_MODEL_DIR": "/private/model",
            "HYMT_LLAMA_SERVER": "/private/helper",
            "BILINGUAL_TRANSLATION_MANIFEST": "/private/manifest.json",
            "BILINGUAL_TRANSLATION_REPORT": "report.json",
            "TRANSLATION_QUALIFICATION_SOURCE_BUNDLE_SHA256": String(
                repeating: "a",
                count: 64
            ),
            "TRANSLATION_QUALIFICATION_TEST_EXECUTABLE_SHA256": String(
                repeating: "b",
                count: 64
            ),
        ]
    }
}

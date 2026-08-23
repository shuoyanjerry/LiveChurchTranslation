import Testing
import TranslationQualificationSupport

@Suite("Hy-MT2 private negation diagnostic configuration")
struct HyMTNegationDiagnosticConfigurationTests {
    @Test func absentOptInNeverRequestsPrivateModelWork() throws {
        let environment = ["HYMT_MODEL_DIR": "/workspace/model"]
        #expect(!HyMTNegationDiagnosticConfiguration.isRequested(environment))
        #expect(try HyMTNegationDiagnosticConfiguration.load(environment) == nil)
    }

    @Test func malformedOrIncompleteOptInFailsClosed() {
        #expect(throws: TranslationQualificationError.self) {
            _ = try HyMTNegationDiagnosticConfiguration.load([
                HyMTNegationDiagnosticConfiguration.optInKey: "yes"
            ])
        }
        #expect(throws: TranslationQualificationError.self) {
            _ = try HyMTNegationDiagnosticConfiguration.load([
                HyMTNegationDiagnosticConfiguration.optInKey: "1"
            ])
        }
    }

    @Test func completeOptInAcceptsOnlyWorkspaceInputsAndPrivateFilename() throws {
        let loaded = try HyMTNegationDiagnosticConfiguration.load(completeEnvironment())
        let configuration = try #require(loaded)
        #expect(configuration.reportFilename == "negation-diagnostic.json")

        var unsafe = completeEnvironment()
        unsafe["BILINGUAL_TRANSLATION_CLASSIFIED_REPORT"] = "/outside/report.json"
        #expect(throws: TranslationQualificationError.self) {
            _ = try HyMTNegationDiagnosticConfiguration.load(unsafe)
        }

        var overwrite = completeEnvironment()
        overwrite["BILINGUAL_TRANSLATION_CLASSIFIED_REPORT"] =
            "/workspace/.artifacts/translation-qualification/negation-diagnostic.json"
        #expect(throws: TranslationQualificationError.self) {
            _ = try HyMTNegationDiagnosticConfiguration.load(overwrite)
        }
    }

    private func completeEnvironment() -> [String: String] {
        [
            HyMTNegationDiagnosticConfiguration.optInKey: "1",
            "TRANSLATION_QUALIFICATION_WORKSPACE_ROOT": "/workspace",
            "HYMT_MODEL_DIR": "/workspace/model",
            "HYMT_LLAMA_SERVER": "/workspace/helper",
            "BILINGUAL_TRANSLATION_MANIFEST": "/workspace/private/manifest.json",
            "BILINGUAL_TRANSLATION_CLASSIFIED_REPORT": "/workspace/private/report.json",
            "BILINGUAL_NEGATION_DIAGNOSTIC_REPORT": "negation-diagnostic.json",
        ]
    }
}

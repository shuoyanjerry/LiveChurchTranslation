import Testing
import TranslationQualificationSupport

@Suite struct TranslationQualificationProvenanceTests {
    @Test func configurationHashIsCanonicalAndRequiresEvidencePolicy() throws {
        let first = settings()
        let second = Dictionary(uniqueKeysWithValues: first.reversed())
        #expect(
            try TranslationConfigurationHasher.hash(settings: first)
                == TranslationConfigurationHasher.hash(settings: second)
        )
        var missingPolicy = first
        missingPolicy.removeValue(forKey: "qualificationGlossaryCatalogPolicy")
        #expect(throws: TranslationQualificationError.self) {
            _ = try TranslationConfigurationHasher.hash(settings: missingPolicy)
        }
    }

    @Test func builderRejectsConfigurationDigestNotDerivedFromProviderSettings() throws {
        let fixture = try SyntheticTranslationWorkspace()
        let corpus = try fixture.load()
        let report = try SyntheticTranslationReportFactory.build(corpus: corpus)
        let value = try #require(report.executionProvenance)
        let stale = TranslationExecutionProvenance(
            buildConfiguration: value.buildConfiguration,
            sourceBundle: value.sourceBundle,
            testExecutable: value.testExecutable,
            model: value.model,
            helper: value.helper,
            runtimeBundle: value.runtimeBundle,
            configurationSHA256: String(repeating: "0", count: 64),
            manifestSHA256: value.manifestSHA256,
            corpusSchemaSHA256: value.corpusSchemaSHA256
        )

        #expect(throws: TranslationQualificationError.self) {
            _ = try TranslationQualificationReportBuilder.build(
                generatedAt: report.generatedAt,
                corpus: corpus,
                provider: report.provider,
                environment: report.environment,
                executionProvenance: stale,
                attempts: report.attempts
            )
        }
    }

    private func settings() -> [String: String] {
        [
            "buildConfiguration": "release",
            "discourseContextEntries": "2",
            "qualificationGlossaryCatalogPolicy": "synthetic-v1",
            "qualificationGlossaryCatalogSHA256": String(repeating: "a", count: 64),
            "translationContextEntries": "2",
        ]
    }
}

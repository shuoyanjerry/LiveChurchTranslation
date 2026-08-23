enum TranslationProvenanceValidator {
    static func validate(
        _ value: TranslationExecutionProvenance,
        corpus: TranslationQualificationCorpus,
        provider: TranslationQualificationProvider
    ) throws {
        try require(value.version == TranslationExecutionProvenance.currentVersion)
        try require(value.buildConfiguration == "release")
        try validate(value.sourceBundle)
        try validate(value.runtimeBundle)
        try validate(value.testExecutable)
        try validate(value.model)
        try validate(value.helper)
        try require(
            value.configurationSHA256
                == TranslationConfigurationHasher.hash(settings: provider.settings)
        )
        try require(value.model.sha256 == provider.modelSHA256)
        try require(value.helper.sha256 == provider.runtimeSHA256)
        try require(value.manifestSHA256 == corpus.manifestSHA256)
        try require(value.corpusSchemaSHA256 == corpus.schemaSHA256)
    }

    static func isReleaseBound(_ report: TranslationQualificationReport) -> Bool {
        guard report.schemaVersion == 2, let value = report.executionProvenance else {
            return false
        }
        return isStructurallyValid(value)
            && value.configurationSHA256
                == (try? TranslationConfigurationHasher.hash(
                    settings: report.provider.settings
                ))
            && value.model.sha256 == report.provider.modelSHA256
            && value.helper.sha256 == report.provider.runtimeSHA256
            && value.manifestSHA256 == report.manifestSHA256
            && value.corpusSchemaSHA256 == report.schemaSHA256
            && report.aggregate == TranslationQualificationReportBuilder.aggregate(report.attempts)
    }

    static func isReleaseBound(
        _ report: TranslationQualificationReport,
        expectation: TranslationReleaseExpectation
    ) -> Bool {
        guard isReleaseBound(report), let provenance = report.executionProvenance else {
            return false
        }
        guard
            provenance == expectation.executionProvenance
                && report.manifestSHA256 == expectation.executionProvenance.manifestSHA256
                && report.schemaSHA256 == expectation.executionProvenance.corpusSchemaSHA256
                && report.attempts.count == expectation.attemptCount
                && TranslationAttemptIdentityDigest.hash(report.attempts)
                    == expectation.attemptIdentitySHA256
                && report.attempts == expectation.trustedAttempts
        else { return false }
        let rebuilt = try? TranslationQualificationReportBuilder.build(
            generatedAt: report.generatedAt,
            corpus: expectation.corpus,
            provider: expectation.provider,
            environment: expectation.environment,
            executionProvenance: expectation.executionProvenance,
            attempts: report.attempts
        )
        return rebuilt == report
    }

    static func isStructurallyValid(_ value: TranslationExecutionProvenance) -> Bool {
        value.version == TranslationExecutionProvenance.currentVersion
            && value.buildConfiguration == "release"
            && isValid(value.sourceBundle)
            && isValid(value.runtimeBundle)
            && isValid(value.testExecutable)
            && isValid(value.model)
            && isValid(value.helper)
            && isSHA(value.configurationSHA256)
            && isSHA(value.manifestSHA256)
            && isSHA(value.corpusSchemaSHA256)
    }

    private static func validate(_ value: TranslationQualificationArtifactDigest) throws {
        try require(isValid(value))
    }

    private static func validate(_ value: TranslationQualificationBundleDigest) throws {
        try require(isValid(value))
    }

    private static func isValid(_ value: TranslationQualificationArtifactDigest) -> Bool {
        value.byteCount > 0 && isSHA(value.sha256)
    }

    private static func isValid(_ value: TranslationQualificationBundleDigest) -> Bool {
        value.format == TranslationExecutionProvenance.bundleFormat
            && value.entryCount > 0
            && value.byteCount > 0
            && isSHA(value.sha256)
    }

    static func isSHA(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    private static func require(_ condition: Bool) throws {
        guard condition else {
            throw TranslationQualificationError.invalidReport(
                "translation qualification execution provenance is invalid"
            )
        }
    }
}

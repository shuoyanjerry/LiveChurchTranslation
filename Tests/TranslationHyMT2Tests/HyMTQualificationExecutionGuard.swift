import Foundation
import TranslationQualificationSupport

struct HyMTQualificationExecutionGuard {
    private let sourceBundle: TranslationQualificationBundleDigest
    private let testExecutable: TranslationQualificationArtifactDigest
    private let runtime: HyMTQualificationRuntimeSnapshot
    private let configurationSHA256: String
    private let manifestSHA256: String
    private let schemaSHA256: String

    static func begin(
        configuration: HyMTQualificationConfiguration,
        corpus: TranslationQualificationCorpus
    ) throws -> Self {
        let source = try HyMTQualificationSourceBundle.capture(
            workspaceRoot: configuration.workspaceRoot
        )
        let executable = try HyMTQualificationExecutableIdentity.capture()
        try require(
            source.sha256 == configuration.expectedSourceBundleSHA256,
            "source bundle does not match the release-build preflight"
        )
        try require(
            executable.sha256 == configuration.expectedTestExecutableSHA256,
            "test executable does not match the release-build preflight"
        )
        return try Self(
            sourceBundle: source,
            testExecutable: executable,
            runtime: HyMTQualificationRuntimeVerifier.verify(configuration),
            configurationSHA256: TranslationConfigurationHasher.hash(
                settings: configuration.providerSettings
            ),
            manifestSHA256: corpus.manifestSHA256,
            schemaSHA256: corpus.schemaSHA256
        )
    }

    func finalize(
        configuration: HyMTQualificationConfiguration
    ) throws -> TranslationExecutionProvenance {
        try revalidate(configuration: configuration)
        return provenance
    }

    func revalidate(
        configuration: HyMTQualificationConfiguration
    ) throws {
        let source = try HyMTQualificationSourceBundle.capture(
            workspaceRoot: configuration.workspaceRoot
        )
        let executable = try HyMTQualificationExecutableIdentity.capture()
        let currentRuntime = try HyMTQualificationRuntimeVerifier.verify(configuration)
        let configurationHash = try TranslationConfigurationHasher.hash(
            settings: configuration.providerSettings
        )
        let corpus = try TranslationQualificationCorpusLoader.load(
            manifestURL: configuration.manifestURL,
            workspaceRoot: configuration.workspaceRoot,
            expectedManifestSHA256: HyMTQualificationConfiguration.manifestSHA256,
            expectedSchemaSHA256: HyMTQualificationConfiguration.schemaSHA256
        )
        try validate(
            source: source,
            executable: executable,
            runtime: currentRuntime,
            configurationHash: configurationHash,
            corpus: corpus
        )
    }

    func releaseExpectation(
        corpus: TranslationQualificationCorpus,
        provider: TranslationQualificationProvider,
        environment: TranslationQualificationEnvironment,
        attempts: [TranslationQualificationAttempt]
    ) throws -> TranslationReleaseExpectation {
        try TranslationReleaseExpectation(
            trustedExecutionProvenance: provenance,
            corpus: corpus,
            provider: provider,
            environment: environment,
            attempts: attempts
        )
    }

    private var provenance: TranslationExecutionProvenance {
        TranslationExecutionProvenance(
            buildConfiguration: "release",
            sourceBundle: sourceBundle,
            testExecutable: testExecutable,
            model: runtime.model,
            helper: runtime.helper,
            runtimeBundle: runtime.runtimeBundle,
            configurationSHA256: configurationSHA256,
            manifestSHA256: manifestSHA256,
            corpusSchemaSHA256: schemaSHA256
        )
    }

    private func validate(
        source: TranslationQualificationBundleDigest,
        executable: TranslationQualificationArtifactDigest,
        runtime: HyMTQualificationRuntimeSnapshot,
        configurationHash: String,
        corpus: TranslationQualificationCorpus
    ) throws {
        try Self.require(source == sourceBundle, "source bundle changed during qualification")
        try Self.require(executable == testExecutable, "test executable changed during qualification")
        try Self.require(runtime == self.runtime, "model or runtime changed during qualification")
        try Self.require(
            configurationHash == configurationSHA256,
            "qualification configuration changed during qualification"
        )
        try Self.require(
            corpus.manifestSHA256 == manifestSHA256 && corpus.schemaSHA256 == schemaSHA256,
            "qualification corpus identity changed during qualification"
        )
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw TranslationQualificationError.invalidReport(message) }
    }
}

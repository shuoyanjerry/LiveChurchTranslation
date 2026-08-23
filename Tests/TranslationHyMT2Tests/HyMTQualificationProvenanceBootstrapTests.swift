import Foundation
import Testing
import TranslationQualificationSupport

@Suite("HyMTProvenanceBootstrapTests")
struct HyMTProvenanceBootstrapTests {
    @Test func fingerprintsWorkspaceAndActualTestExecutable() throws {
        let environment = ProcessInfo.processInfo.environment
        let root = URL(
            fileURLWithPath: environment["TRANSLATION_QUALIFICATION_WORKSPACE_ROOT"]
                ?? FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        let releaseBootstrap = environment["TRANSLATION_QUALIFICATION_BOOTSTRAP"] == "1"
        let source = try HyMTQualificationSourceBundle.capture(workspaceRoot: root)
        let executable = try HyMTQualificationExecutableIdentity.capture(
            requireRelease: releaseBootstrap
        )

        #expect(source.entryCount > 0)
        #expect(source.sha256.count == 64)
        #expect(executable.sha256.count == 64)
        if releaseBootstrap {
            print("HYMT_SOURCE_BUNDLE_SHA256=\(source.sha256)")
            print("HYMT_TEST_EXECUTABLE_SHA256=\(executable.sha256)")
        }
    }
}

@Suite("HyMTQualificationPostflightTests")
struct HyMTQualificationPostflightTests {
    @Test(
        .enabled(
            if: ProcessInfo.processInfo.environment["TRANSLATION_QUALIFICATION_POSTFLIGHT"]
                == "1",
            "Runs only after an explicitly requested private qualification."
        )
    )
    func revalidatesAllReleaseInputsWithoutRunningModel() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["TRANSLATION_QUALIFICATION_POSTFLIGHT"] == "1" else { return }
        let loadedConfiguration = try HyMTQualificationConfiguration.load(environment)
        let configuration = try #require(loadedConfiguration)
        try runPostflight(configuration)
    }

    private func runPostflight(_ configuration: HyMTQualificationConfiguration) throws {
        let corpus = try TranslationQualificationCorpusLoader.load(
            manifestURL: configuration.manifestURL,
            workspaceRoot: configuration.workspaceRoot,
            expectedManifestSHA256: HyMTQualificationConfiguration.manifestSHA256,
            expectedSchemaSHA256: HyMTQualificationConfiguration.schemaSHA256
        )
        let executionGuard = try HyMTQualificationExecutionGuard.begin(
            configuration: configuration,
            corpus: corpus
        )
        let snapshot = try HyMTQualificationReportSnapshot.load(
            workspaceRoot: configuration.workspaceRoot,
            reportFilename: configuration.reportFilename
        )
        let provenance = try executionGuard.finalize(configuration: configuration)
        let attestation = try HyMTQualificationPostflightValidator.validate(
            snapshot: snapshot,
            corpus: corpus,
            provenance: provenance,
            configuration: configuration,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        try executionGuard.revalidate(configuration: configuration)
        try snapshot.requireUnchanged(
            workspaceRoot: configuration.workspaceRoot,
            reportFilename: configuration.reportFilename
        )
        let sidecarURL = try HyMTQualificationPostflightWriter.writePrivate(
            attestation,
            workspaceRoot: configuration.workspaceRoot,
            reportFilename: configuration.reportFilename
        )
        let sidecarSHA256 = try TranslationQualificationSHA256.hash(fileAt: sidecarURL)
        print("POSTFLIGHT_VERIFIED=true")
        print("POSTFLIGHT_ATTESTATION_SHA256=\(sidecarSHA256)")
    }
}

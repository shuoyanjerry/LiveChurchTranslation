import ASRAPI
import ASRFunASRNano
import ASRQualificationSupport
import Foundation
import Testing

@Suite("Fun-ASR-Nano public spiritual-corpus qualification")
struct FunASRSpiritualCorpusQualificationTests {
    @Test(
        "replays the complete frozen public-domain Manifest V2",
        .enabled(if: Self.hasEnvironment, "Requires model and frozen qualification inputs.")
    )
    func replaysCorpusWhenSupplied() async throws {
        let environment = ProcessInfo.processInfo.environment
        let inputs = try FunQualificationInputs(environment: environment)
        let fixture = try FunQualificationFixture.load(inputs: inputs)
        try FunASRNanoModelVerifier().verify(directory: inputs.modelDirectory)
        let verifiedModelRevision = FunQualificationConfiguration.modelRevision
        let host = try FunQualificationHostEnvironment.detect(environment: environment)
        let provider = FunASRNanoProvider(
            configuration: FunQualificationConfiguration.providerConfiguration
        )
        let evaluations = try await evaluate(
            fixture: fixture,
            inputs: inputs,
            provider: provider
        )
        let report = try ASRQualificationReportV3Builder().build(
            qualificationManifestSHA256: FunQualificationConfiguration.frozenManifestSHA256,
            manifest: fixture.manifest,
            provider: FunQualificationConfiguration.providerMetadata(
                verifiedModelRevision: verifiedModelRevision
            ),
            environment: host,
            clips: evaluations
        )
        try FunQualificationReportWriter.write(report, to: inputs.reportURL)
        print("FUNASR_ASR_REPORT=\(inputs.reportURL.path)")
        print("FUNASR_ASR_AGGREGATE=\(report.aggregate)")
        #expect(report.clips.count == 6)
        #expect(report.clips.flatMap(\.attempts).count == 220)
        #expect(
            report.qualificationManifestSHA256
                == FunQualificationConfiguration.frozenManifestSHA256
        )
    }

    private func evaluate(
        fixture: FunQualificationFixture,
        inputs: FunQualificationInputs,
        provider: FunASRNanoProvider
    ) async throws -> [ASRQualificationClipEvaluationInputV3] {
        do {
            try await provider.loadModel(at: inputs.modelDirectory)
            let evaluations = try await FunQualificationRunner().evaluate(
                manifest: fixture.manifest,
                references: fixture.references,
                wavDirectory: inputs.wavDirectory,
                provider: provider
            )
            await provider.unloadModel()
            return evaluations
        } catch {
            await provider.unloadModel()
            throw error
        }
    }
}

extension FunASRSpiritualCorpusQualificationTests {
    fileprivate static var hasEnvironment: Bool {
        let environment = ProcessInfo.processInfo.environment
        return [
            "FUNASR_MODEL_DIR", "MANDARIN_ASR_QUALIFICATION_MANIFEST",
            "MANDARIN_ASR_REFERENCE_MANIFEST", "MANDARIN_ASR_WAV_DIR",
            "FUNASR_ASR_REPORT",
        ].allSatisfy { environment[$0] != nil }
    }
}

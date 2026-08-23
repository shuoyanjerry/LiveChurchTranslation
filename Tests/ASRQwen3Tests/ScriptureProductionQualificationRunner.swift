import ASRQwen3
import Foundation
import ScriptureQualificationSupport
import TranslationHyMT2

struct ScriptureProductionQualificationRunner {
    func run(
        configuration: ScriptureModelQualificationConfiguration,
        now: Date = Date()
    ) async throws -> ScriptureModelQualificationReport {
        let corpus = try ScriptureQualificationCorpusLoader.load(
            manifestURL: configuration.manifestURL,
            privateRoot: configuration.privateRoot,
            expectedManifestSHA256: configuration.manifestSHA256,
            now: now
        )
        let providers = try ScriptureProductionModelIdentity.verify(
            configuration: configuration
        )
        let asr = Qwen3ASRProvider()
        let translator = HyMT2TranslationProvider(
            helperExecutableURL: configuration.hyMTHelperURL
        )
        do {
            try await asr.loadModel(at: configuration.qwenModelDirectory)
            try await translator.loadModel(at: configuration.hyMTModelLocation)
            let report = try await evaluate(
                corpus: corpus,
                asr: asr,
                translator: translator,
                context: ScriptureQualificationRunContext(
                    providers: providers,
                    phase: configuration.phase,
                    generatedAt: now
                )
            )
            await asr.unloadModel()
            await translator.shutdown()
            return report
        } catch {
            await asr.unloadModel()
            await translator.shutdown()
            throw error
        }
    }
}

struct ScriptureQualificationRunContext: Sendable {
    let providers: [ScriptureQualificationProviderIdentity]
    let phase: ScriptureQualificationPhase
    let generatedAt: Date
}

import ASRQualificationSupport
import ASRQwen3
import Foundation

struct QwenQualificationRunner {
    private let manifestDecoder = ASRQualificationManifestDecoder()
    private let wavLoader = ASRQualificationWAVLoader()
    private let reportBuilder = ASRQualificationReportV3Builder()
    private let modelVerifier = QwenQualificationModelVerifier()

    func run(
        inputs: QwenQualificationInputs,
        processEnvironment: [String: String]
    ) async throws -> ASRQualificationReportV3 {
        let manifestData = try Data(contentsOf: inputs.manifestURL, options: .mappedIfSafe)
        let manifestSHA = QwenQualificationHashing.sha256(manifestData)
        guard manifestSHA == QwenQualificationConfiguration.frozenManifestSHA256 else {
            throw QwenQualificationRunError.unexpectedManifestSHA256(manifestSHA)
        }
        let manifest = try manifestDecoder.decode(manifestData)
        let references = try QwenQualificationReferenceCatalog.load(
            from: inputs.referenceManifestURL,
            for: manifest
        )
        try modelVerifier.verify(directory: inputs.modelDirectory)
        let environment = try QwenQualificationHostEnvironment.detect(
            environment: processEnvironment
        )
        let evaluations = try await evaluate(
            manifest: manifest,
            references: references,
            inputs: inputs
        )
        return try reportBuilder.build(
            qualificationManifestSHA256: manifestSHA,
            manifest: manifest,
            provider: QwenQualificationConfiguration.providerMetadata(for: inputs.profile),
            environment: environment,
            clips: evaluations
        )
    }

    private func evaluate(
        manifest: ASRQualificationManifestV2,
        references: QwenQualificationReferenceCatalog,
        inputs: QwenQualificationInputs
    ) async throws -> [ASRQualificationClipEvaluationInputV3] {
        let provider = Qwen3ASRProvider(
            configuration: QwenQualificationConfiguration.providerConfiguration(
                for: inputs.profile
            )
        )
        try await provider.loadModel(at: inputs.modelDirectory)
        do {
            let evaluations = try await evaluate(
                manifest: manifest,
                references: references,
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

    private func evaluate(
        manifest: ASRQualificationManifestV2,
        references: QwenQualificationReferenceCatalog,
        wavDirectory: URL,
        provider: Qwen3ASRProvider
    ) async throws -> [ASRQualificationClipEvaluationInputV3] {
        var evaluations: [ASRQualificationClipEvaluationInputV3] = []
        for clip in manifest.clips {
            guard let reference = references.referencesByID[clip.id] else {
                throw QwenQualificationRunError.missingReference(clip.id)
            }
            let wavURL = try QwenQualificationWAVLocator.url(for: clip.id, in: wavDirectory)
            let loaded = try wavLoader.load(clip: clip, from: wavURL)
            var attempts: [ASRQualificationAttemptV3] = []
            for segment in loaded {
                attempts.append(
                    try await QwenQualificationAttemptRecorder.transcribe(
                        segment,
                        sampleRate: clip.sampleRate,
                        provider: provider
                    )
                )
            }
            evaluations.append(
                ASRQualificationClipEvaluationInputV3(
                    id: clip.id,
                    referenceText: reference,
                    sourceAudioSeconds: Double(clip.totalSamples) / Double(clip.sampleRate),
                    segments: clip.segments,
                    attempts: attempts
                )
            )
        }
        return evaluations
    }
}

enum QwenQualificationRunError: Error, Equatable {
    case unexpectedManifestSHA256(String)
    case missingReference(String)
}

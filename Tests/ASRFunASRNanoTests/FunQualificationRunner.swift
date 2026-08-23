import ASRFunASRNano
import ASRQualificationSupport
import Foundation

struct FunQualificationRunner {
    private let wavLoader = ASRQualificationWAVLoader()

    func evaluate(
        manifest: ASRQualificationManifestV2,
        references: FunQualificationReferenceCatalog,
        wavDirectory: URL,
        provider: FunASRNanoProvider
    ) async throws -> [ASRQualificationClipEvaluationInputV3] {
        var evaluations: [ASRQualificationClipEvaluationInputV3] = []
        evaluations.reserveCapacity(manifest.clips.count)
        for clip in manifest.clips {
            let wavURL = try FunQualificationWAVLocator.url(
                for: clip.id,
                in: wavDirectory
            )
            let loaded = try wavLoader.load(clip: clip, from: wavURL)
            var attempts: [ASRQualificationAttemptV3] = []
            attempts.reserveCapacity(loaded.count)
            for segment in loaded {
                attempts.append(
                    try await FunQualificationAttemptRecorder.transcribe(
                        segment,
                        sampleRate: clip.sampleRate,
                        provider: provider
                    )
                )
            }
            guard let referenceText = references.referencesByID[clip.id] else {
                throw FunQualificationReferenceError.clipSetMismatch
            }
            evaluations.append(
                ASRQualificationClipEvaluationInputV3(
                    id: clip.id,
                    referenceText: referenceText,
                    sourceAudioSeconds: Double(clip.totalSamples) / Double(clip.sampleRate),
                    segments: clip.segments,
                    attempts: attempts
                )
            )
        }
        return evaluations
    }
}

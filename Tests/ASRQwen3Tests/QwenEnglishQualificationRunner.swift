import ASRAPI
import ASRQualificationSupport
import ASRQwen3
import Foundation
import GlossaryAPI
@testable import SessionManagement
import SettingsAPI
import SherpaOnnx
import VADAPI

struct QwenEnglishQualificationRunner {
    static let prompt = ASRContextTermSelector.prompt(
        from: DefaultGlossary.entries,
        mode: .englishToSimplifiedChinese
    )
    static let gate = QwenEnglishGatePolicy(
        minimumClips: 18,
        minimumVoices: 6,
        minimumLocales: 6,
        maximumWeightedWER: 0.02,
        maximumWeightedCER: 0.01,
        maximumClipWER: 0.10,
        maximumRealTimeFactor: 1
    )

    func run(modelDirectory: URL, manifestURL: URL) async throws -> QwenEnglishQualificationReport {
        let manifestData = try Data(contentsOf: manifestURL, options: .mappedIfSafe)
        let manifest = try QwenEnglishCorpusLoader.load(from: manifestURL)
        try QwenQualificationModelVerifier().verify(directory: modelDirectory)
        let provider = Qwen3ASRProvider()
        try await provider.loadModel(at: modelDirectory)
        do {
            let results = try await evaluate(
                manifest,
                directory: manifestURL.deletingLastPathComponent(),
                provider: provider
            )
            await provider.unloadModel()
            return makeReport(manifest, manifestData: manifestData, results: results)
        } catch {
            await provider.unloadModel()
            throw error
        }
    }

    private func evaluate(
        _ manifest: QwenEnglishCorpusManifest,
        directory: URL,
        provider: Qwen3ASRProvider
    ) async throws -> [QwenEnglishClipResult] {
        var results: [QwenEnglishClipResult] = []
        for clip in manifest.clips {
            let url = directory.appending(path: clip.file)
            guard try QwenQualificationHashing.sha256(contentsOf: url) == clip.audioSHA256 else {
                throw QwenEnglishCorpusError.audioHashMismatch(clip.id)
            }
            let wave = SherpaOnnxWaveWrapper.readWave(filename: url.path)
            guard wave.sampleRate == 16_000, !wave.samples.isEmpty else {
                throw QwenEnglishCorpusError.invalidWave(clip.id)
            }
            let duration = Double(wave.samples.count) / Double(wave.sampleRate)
            let speech = SpeechSegment(
                sequenceNumber: UInt64(results.count),
                samples: wave.samples,
                sampleRate: Double(wave.sampleRate),
                startedAt: .zero,
                endedAt: .seconds(duration),
                endReason: .trailingSilence
            )
            let started = ContinuousClock.now
            let utterance = try await provider.transcribe(
                ASRRequest(segment: speech, languageCode: "en", contextPrompt: Self.prompt)
            )
            let elapsed = started.duration(to: .now).qwenQualificationSeconds
            results.append(makeResult(clip, utterance.text, duration: duration, elapsed: elapsed))
        }
        return results
    }

    private func makeResult(
        _ clip: QwenEnglishCorpusClip,
        _ hypothesis: String,
        duration: Double,
        elapsed: Double
    ) -> QwenEnglishClipResult {
        let wer = ASRQualificationTextMetrics.normalizedEnglishWER(
            reference: clip.reference,
            hypothesis: hypothesis
        )
        let cer = ASRQualificationTextMetrics.normalizedStrictCER(
            reference: clip.reference,
            hypothesis: hypothesis
        )
        return QwenEnglishClipResult(
            id: clip.id,
            voice: clip.voice,
            locale: clip.locale,
            reference: clip.reference,
            hypothesis: hypothesis,
            audioSeconds: duration,
            decodeSeconds: elapsed,
            wordEdits: wer.editCount,
            referenceWords: wer.referenceWordCount,
            characterEdits: cer.editCount,
            referenceCharacters: cer.referenceCharacterCount
        )
    }

}

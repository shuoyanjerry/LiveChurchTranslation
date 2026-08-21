import ASRAPI
import ASRNormalizationCore
import ASRQwen3
import Foundation
import SherpaOnnx
import Testing
import VADAPI

@Suite("Qwen3 real-model qualification")
struct Qwen3RealModelSmokeTests {
    @Test(
        "recognizes a supplied Mandarin theological WAV",
        .enabled(
            if: ProcessInfo.processInfo.environment["QWEN_MODEL_DIR"] != nil
                && ProcessInfo.processInfo.environment["QWEN_TEST_WAV"] != nil,
            "Requires QWEN_MODEL_DIR and QWEN_TEST_WAV."
        )
    )
    func recognizesTheologicalAudioWhenSupplied() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard
            let modelPath = environment["QWEN_MODEL_DIR"],
            let wavePath = environment["QWEN_TEST_WAV"]
        else { return }
        try requireExisting(modelPath)
        let (segment, duration) = try segment(from: wavePath)
        let provider = Qwen3ASRProvider()
        try await provider.loadModel(at: URL(fileURLWithPath: modelPath))
        let (result, latency) = try await transcribe(segment, with: provider)
        let normalized = RuleBasedASRTextNormalizer().normalize(result.text, using: [])
        print("QWEN_REAL_RAW_RESULT=\(result.text)")
        print("QWEN_REAL_NORMALIZED_RESULT=\(normalized)")
        print("QWEN_AUDIO_SECONDS=\(duration)")
        print("QWEN_DECODE_DURATION=\(latency)")
        #expect(!result.text.isEmpty)
        for expected in ["救恩", "恩典", "因信称义", "圣灵", "成圣"] {
            #expect(normalized.contains(expected))
        }
        await provider.unloadModel()
    }

    private func segment(from path: String) throws -> (SpeechSegment, Double) {
        try requireExisting(path)
        let wave = SherpaOnnxWaveWrapper.readWave(filename: path)
        #expect(wave.sampleRate == 16_000)
        #expect(!wave.samples.isEmpty)
        let duration = Double(wave.samples.count) / Double(wave.sampleRate)
        return (
            SpeechSegment(
                sequenceNumber: 0,
                samples: wave.samples,
                sampleRate: Double(wave.sampleRate),
                startedAt: .zero,
                endedAt: .seconds(duration),
                endReason: .trailingSilence
            ),
            duration
        )
    }

    private func transcribe(
        _ segment: SpeechSegment,
        with provider: Qwen3ASRProvider
    ) async throws -> (RecognizedUtterance, Duration) {
        let clock = ContinuousClock()
        let started = clock.now
        let result = try await provider.transcribe(
            ASRRequest(
                segment: segment,
                contextPrompt: "救恩,恩典,因信称义,圣灵,成圣"
            )
        )
        return (result, started.duration(to: clock.now))
    }

    private func requireExisting(_ path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw CocoaError(.fileNoSuchFile)
        }
    }
}

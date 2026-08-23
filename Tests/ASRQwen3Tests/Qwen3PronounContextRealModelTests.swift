import ASRAPI
import ASRQwen3
import Foundation
import SherpaOnnx
import Testing
import VADAPI

@Suite("Qwen3 pronoun-context qualification")
struct Qwen3PronounContextRealModelTests {
    @Test(
        "compares documented hotword prompting on a supplied Mandarin pronoun clip",
        .enabled(
            if: ProcessInfo.processInfo.environment["QWEN_MODEL_DIR"] != nil
                && ProcessInfo.processInfo.environment["QWEN_PRONOUN_WAV"] != nil,
            "Requires QWEN_MODEL_DIR and QWEN_PRONOUN_WAV."
        )
    )
    func comparesPromptVariantsWhenSupplied() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard
            let modelPath = environment["QWEN_MODEL_DIR"],
            let wavePath = environment["QWEN_PRONOUN_WAV"]
        else { return }
        let segment = try makeSegment(wavePath)
        let provider = Qwen3ASRProvider()
        try await provider.loadModel(at: URL(fileURLWithPath: modelPath))

        for fixture in Self.fixtures {
            let clock = ContinuousClock()
            let started = clock.now
            let result = try await provider.transcribe(
                ASRRequest(segment: segment, contextPrompt: fixture.prompt)
            )
            print("QWEN_PRONOUN_\(fixture.name)=\(result.text)")
            print("QWEN_PRONOUN_DURATION_\(fixture.name)=\(started.duration(to: clock.now))")
            #expect(!result.text.isEmpty)
        }
        await provider.unloadModel()
    }

    private static let fixtures = [
        Fixture(name: "NO_CONTEXT", prompt: ""),
        Fixture(name: "ANTECEDENT_TERM", prompt: "法老的女儿"),
        Fixture(name: "PREVIOUS_TURN", prompt: "他将法老的女儿带出大卫城"),
        Fixture(name: "ANSWER_BIASED", prompt: "法老的女儿,她,为她建造的宫殿"),
    ]

    private func makeSegment(_ path: String) throws -> SpeechSegment {
        guard FileManager.default.fileExists(atPath: path) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let wave = SherpaOnnxWaveWrapper.readWave(filename: path)
        #expect(wave.sampleRate == 16_000)
        #expect(!wave.samples.isEmpty)
        let duration = Double(wave.samples.count) / Double(wave.sampleRate)
        return SpeechSegment(
            sequenceNumber: 0,
            samples: wave.samples,
            sampleRate: Double(wave.sampleRate),
            startedAt: .zero,
            endedAt: .seconds(duration),
            endReason: .trailingSilence
        )
    }
}

private struct Fixture {
    let name: String
    let prompt: String
}

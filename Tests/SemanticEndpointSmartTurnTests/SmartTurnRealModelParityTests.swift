import Foundation
import SemanticEndpointAPI
import SemanticEndpointSmartTurn
import Testing

@Suite("Smart Turn real-model qualification")
struct SmartTurnRealModelParityTests {
    @Test(
        "matches Python probability for Mandarin theology audio",
        .enabled(
            if: ProcessInfo.processInfo.environment["SMART_TURN_REAL_MODEL_TESTS"] == "1",
            "Set SMART_TURN_REAL_MODEL_TESTS=1 to run the pinned local model."
        )
    )
    func matchesPythonReference() async throws {
        let environment = ProcessInfo.processInfo.environment
        let modelPath =
            environment["SMART_TURN_MODEL_PATH"]
            ?? ".artifacts/model-smoke/smart-turn/smart-turn-v3.2-cpu.onnx"
        let wavePath =
            environment["SMART_TURN_TEST_WAV"]
            ?? ".artifacts/model-smoke/theology.wav"
        let modelLocation = URL(fileURLWithPath: modelPath)
        let wave = try PCM16WaveReader.read(URL(fileURLWithPath: wavePath))
        let analyzer = SmartTurnSemanticEndpointAnalyzer()
        try await analyzer.loadModel(at: modelLocation)
        let result = try await analyzer.analyze(
            SemanticTurnAudio(samples: wave.samples, sampleRate: wave.sampleRate)
        )
        print("SMART_TURN_ORT_VERSION=\(SmartTurnSemanticEndpointAnalyzer.onnxRuntimeVersion)")
        print("SMART_TURN_THEOLOGY_PROBABILITY=\(result.probability)")
        #expect(abs(result.probability - 0.952_276_23) < 0.000_2)
        #expect(result.decision == .complete)
        #expect(result.completionThreshold == 0.5)
        await analyzer.shutdown()
        #expect(
            await analysisError(analyzer) == .modelNotLoaded
        )
    }

    private func analysisError(
        _ analyzer: SmartTurnSemanticEndpointAnalyzer
    ) async -> SemanticEndpointError? {
        do {
            _ = try await analyzer.analyze(SemanticTurnAudio(samples: [0]))
            return nil
        } catch let error as SemanticEndpointError {
            return error
        } catch {
            return nil
        }
    }
}

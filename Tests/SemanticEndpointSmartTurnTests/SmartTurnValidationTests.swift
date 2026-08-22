import Foundation
import SemanticEndpointAPI
import SemanticEndpointSmartTurn
import Testing

@Suite("Smart Turn validation")
struct SmartTurnValidationTests {
    @Test("rejects invalid thresholds")
    func rejectsInvalidThresholds() {
        for threshold in [Float.nan, -0.01, 1.01] {
            #expect(throws: SemanticEndpointError.self) {
                _ = try SmartTurnConfiguration(completionThreshold: threshold)
            }
        }
    }

    @Test("reports audio validation and unloaded state explicitly")
    func reportsValidationFailures() async {
        let analyzer = SmartTurnSemanticEndpointAnalyzer()
        let valid = SemanticTurnAudio(samples: [0])
        #expect(await error(from: valid, analyzer: analyzer) == .modelNotLoaded)
        #expect(
            await error(
                from: SemanticTurnAudio(samples: [0], sampleRate: 48_000),
                analyzer: analyzer
            ) == .invalidSampleRate(expected: 16_000, actual: 48_000)
        )
        #expect(
            await error(
                from: SemanticTurnAudio(samples: [0], channelCount: 2),
                analyzer: analyzer
            ) == .invalidChannelCount(expected: 1, actual: 2)
        )
        #expect(
            await error(from: SemanticTurnAudio(samples: []), analyzer: analyzer)
                == .invalidSampleCount(0)
        )
        #expect(
            await error(from: SemanticTurnAudio(samples: [0, .nan]), analyzer: analyzer)
                == .nonFiniteSample(index: 1)
        )
    }

    @Test("maps task cancellation to the public error")
    func reportsCancellation() async {
        let analyzer = SmartTurnSemanticEndpointAnalyzer()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await error(
                from: SemanticTurnAudio(samples: [0]),
                analyzer: analyzer
            )
        }
        #expect(await task.value == .cancelled)
    }

    @Test("rejects absent and unpinned model files")
    func validatesModelIdentity() async throws {
        let analyzer = SmartTurnSemanticEndpointAnalyzer()
        let absent = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        #expect(await loadError(absent, analyzer: analyzer) == .modelFileUnavailable(absent.path))

        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try Data("not a model".utf8).write(to: temporary, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporary) }
        guard
            case .modelIntegrityMismatch(let expected, _) = await loadError(
                temporary,
                analyzer: analyzer
            )
        else {
            Issue.record("Expected an integrity mismatch.")
            return
        }
        #expect(expected == SmartTurnModelIdentity.version3Point2CPU.sha256)
    }

    private func error(
        from audio: SemanticTurnAudio,
        analyzer: SmartTurnSemanticEndpointAnalyzer
    ) async -> SemanticEndpointError? {
        do {
            _ = try await analyzer.analyze(audio)
            return nil
        } catch let error as SemanticEndpointError {
            return error
        } catch {
            return nil
        }
    }

    private func loadError(
        _ location: URL,
        analyzer: SmartTurnSemanticEndpointAnalyzer
    ) async -> SemanticEndpointError? {
        do {
            try await analyzer.loadModel(at: location)
            return nil
        } catch let error as SemanticEndpointError {
            return error
        } catch {
            return nil
        }
    }
}

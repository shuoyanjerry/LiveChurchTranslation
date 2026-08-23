import ASRAPI
import ASRNormalizationCore
import Foundation
import Testing

struct ASRBenchmarkRunInput {
    let fixtures: [ASRBenchmarkFixture]
    let projectRoot: URL
    let contextPrompt: String
}

struct ASRBenchmarkProviderResult {
    let load: ASRBenchmarkLoad
    let observations: [ASRBenchmarkObservation]
}

struct ASRBenchmarkModelDirectories {
    let funASR: URL
    let qwen: URL
}

struct ASRBenchmarkComparison {
    let loads: [ASRBenchmarkLoad]
    let observations: [ASRBenchmarkObservation]
}

enum ASRBenchmarkQualificationRunner {
    static func compare(
        funASR: any ASRProvider,
        qwen: any ASRProvider,
        directories: ASRBenchmarkModelDirectories,
        input: ASRBenchmarkRunInput
    ) async throws -> ASRBenchmarkComparison {
        let funResult = try await evaluate(
            provider: funASR,
            modelDirectory: directories.funASR,
            input: input
        )
        let qwenResult = try await evaluate(
            provider: qwen,
            modelDirectory: directories.qwen,
            input: input
        )
        return ASRBenchmarkComparison(
            loads: [funResult.load, qwenResult.load],
            observations: funResult.observations + qwenResult.observations
        )
    }

    static func evaluate(
        provider: any ASRProvider,
        modelDirectory: URL,
        input: ASRBenchmarkRunInput
    ) async throws -> ASRBenchmarkProviderResult {
        let load = try await ASRProviderBenchmark.load(provider, from: modelDirectory)
        let observations = await observe(provider: provider, input: input)
        await provider.unloadModel()
        return ASRBenchmarkProviderResult(load: load, observations: observations)
    }

    private static func observe(
        provider: any ASRProvider,
        input: ASRBenchmarkRunInput
    ) async -> [ASRBenchmarkObservation] {
        let normalizer = RuleBasedASRTextNormalizer()
        var results: [ASRBenchmarkObservation] = []
        for fixture in input.fixtures {
            do {
                let segment = try ASRBenchmarkAudioLoader.load(
                    fixture,
                    projectRoot: input.projectRoot
                )
                results.append(
                    await ASRProviderBenchmark.observe(
                        provider: provider,
                        fixture: fixture,
                        segment: segment,
                        contextPrompt: input.contextPrompt,
                        normalizer: normalizer
                    ))
            } catch {
                Issue.record("Could not load \(fixture.name): \(error)")
            }
        }
        results.append(
            await silenceObservation(
                provider: provider,
                contextPrompt: input.contextPrompt,
                normalizer: normalizer
            ))
        return results
    }

    private static func silenceObservation(
        provider: any ASRProvider,
        contextPrompt: String,
        normalizer: RuleBasedASRTextNormalizer
    ) async -> ASRBenchmarkObservation {
        let fixture = ASRBenchmarkFixture(
            name: "synthetic-silence",
            speaker: "none",
            path: "",
            startSeconds: 0,
            durationSeconds: 3,
            expectedTerms: []
        )
        return await ASRProviderBenchmark.observe(
            provider: provider,
            fixture: fixture,
            segment: ASRBenchmarkAudioLoader.silence(),
            contextPrompt: contextPrompt,
            normalizer: normalizer
        )
    }
}

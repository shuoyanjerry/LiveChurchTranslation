import ASRAPI
import ASRNormalizationAPI
import Foundation
import VADAPI

enum ASRProviderBenchmark {
    static func load(
        _ provider: any ASRProvider,
        from modelDirectory: URL
    ) async throws -> ASRBenchmarkLoad {
        let clock = ContinuousClock()
        let started = clock.now
        try await provider.loadModel(at: modelDirectory)
        return ASRBenchmarkLoad(
            provider: provider.identifier,
            seconds: seconds(started.duration(to: clock.now))
        )
    }

    static func observe(
        provider: any ASRProvider,
        fixture: ASRBenchmarkFixture,
        segment: SpeechSegment,
        contextPrompt: String,
        normalizer: any ASRTextNormalizer
    ) async -> ASRBenchmarkObservation {
        let clock = ContinuousClock()
        let started = clock.now
        let context = ASRBenchmarkObservationContext(
            provider: provider.identifier,
            fixture: fixture,
            audioSeconds: seconds(segment.duration)
        )
        do {
            let result = try await provider.transcribe(
                ASRRequest(segment: segment, contextPrompt: contextPrompt)
            )
            let elapsed = seconds(started.duration(to: clock.now))
            return success(
                context: context,
                result: result,
                elapsed: elapsed,
                normalizer: normalizer
            )
        } catch {
            let elapsed = seconds(started.duration(to: clock.now))
            return failure(context: context, error: error, elapsed: elapsed)
        }
    }

    private static func success(
        context: ASRBenchmarkObservationContext,
        result: RecognizedUtterance,
        elapsed: Double,
        normalizer: any ASRTextNormalizer
    ) -> ASRBenchmarkObservation {
        let normalized = normalizer.normalize(result.text, using: [])
        return observation(
            ASRBenchmarkObservationInput(
                provider: context.provider,
                fixture: context.fixture,
                audioSeconds: context.audioSeconds,
                elapsed: elapsed,
                rawText: result.rawText,
                normalizedText: normalized,
                matchedTerms: context.fixture.expectedTerms.filter(normalized.contains),
                repetition: false,
                error: nil
            ))
    }

    private static func failure(
        context: ASRBenchmarkObservationContext,
        error: Error,
        elapsed: Double
    ) -> ASRBenchmarkObservation {
        let message = error.localizedDescription
        return observation(
            ASRBenchmarkObservationInput(
                provider: context.provider,
                fixture: context.fixture,
                audioSeconds: context.audioSeconds,
                elapsed: elapsed,
                rawText: "",
                normalizedText: "",
                matchedTerms: [],
                repetition: message.localizedCaseInsensitiveContains("repet"),
                error: message
            ))
    }

    private static func observation(
        _ input: ASRBenchmarkObservationInput
    ) -> ASRBenchmarkObservation {
        return ASRBenchmarkObservation(
            provider: input.provider,
            fixture: input.fixture.name,
            speaker: input.fixture.speaker,
            audioSeconds: input.audioSeconds,
            decodeSeconds: input.elapsed,
            realTimeFactor: input.elapsed / max(input.audioSeconds, 0.001),
            rawText: input.rawText,
            normalizedText: input.normalizedText,
            expectedTerms: input.fixture.expectedTerms,
            matchedTerms: input.matchedTerms,
            repetitionDetected: input.repetition,
            error: input.error
        )
    }

    private static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}

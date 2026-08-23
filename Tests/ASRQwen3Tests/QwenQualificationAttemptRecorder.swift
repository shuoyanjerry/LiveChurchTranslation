import ASRAPI
import ASRQualificationSupport
import ASRQwen3

enum QwenQualificationAttemptRecorder {
    static func transcribe(
        _ loaded: ASRQualificationLoadedSegment,
        sampleRate: Int,
        provider: Qwen3ASRProvider
    ) async throws -> ASRQualificationAttemptV3 {
        let speech = try QwenQualificationEndReason.speechSegment(
            loaded: loaded,
            sampleRate: sampleRate
        )
        let started = ContinuousClock.now
        do {
            let result = try await provider.transcribe(
                ASRRequest(
                    segment: speech,
                    languageCode: QwenQualificationConfiguration.languageCode,
                    contextPrompt: QwenQualificationConfiguration.prompt
                )
            )
            return attempt(
                loaded,
                elapsed: started.duration(to: .now).qwenQualificationSeconds,
                hypothesis: result.text
            )
        } catch {
            return failure(
                loaded,
                elapsed: started.duration(to: .now).qwenQualificationSeconds,
                error: error
            )
        }
    }

    private static func attempt(
        _ loaded: ASRQualificationLoadedSegment,
        elapsed: Double,
        hypothesis: String
    ) -> ASRQualificationAttemptV3 {
        ASRQualificationAttemptV3(
            sequence: loaded.definition.sequence,
            inputSampleCount: loaded.samples.count,
            pcmSHA256: loaded.definition.pcmSHA256,
            elapsedSeconds: elapsed,
            status: .success,
            hypothesis: hypothesis
        )
    }

    private static func failure(
        _ loaded: ASRQualificationLoadedSegment,
        elapsed: Double,
        error: Error
    ) -> ASRQualificationAttemptV3 {
        ASRQualificationAttemptV3(
            sequence: loaded.definition.sequence,
            inputSampleCount: loaded.samples.count,
            pcmSHA256: loaded.definition.pcmSHA256,
            elapsedSeconds: elapsed,
            status: .failure,
            failureCode: QwenQualificationFailureCode.value(for: error)
        )
    }
}

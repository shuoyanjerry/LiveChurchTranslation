import ASRAPI
import ASRFunASRNano
import ASRQualificationSupport

enum FunQualificationAttemptRecorder {
    static func transcribe(
        _ loaded: ASRQualificationLoadedSegment,
        sampleRate: Int,
        provider: FunASRNanoProvider
    ) async throws -> ASRQualificationAttemptV3 {
        let segment = try FunQualificationSegmentFactory.speechSegment(
            loaded: loaded,
            sampleRate: sampleRate
        )
        let started = ContinuousClock.now
        do {
            let result = try await provider.transcribe(
                ASRRequest(
                    segment: segment,
                    languageCode: FunQualificationConfiguration.languageCode
                )
            )
            return success(
                loaded,
                elapsed: started.duration(to: .now).funQualificationSeconds,
                hypothesis: result.text
            )
        } catch {
            return failure(
                loaded,
                elapsed: started.duration(to: .now).funQualificationSeconds,
                error: error
            )
        }
    }

    private static func success(
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
            failureCode: FunQualificationFailureCode.value(for: error)
        )
    }
}

import VADAPI
import WebRTCVADC

/// Stateful libfvad adapter with the deployed sermon energy fallback.
///
/// One `CalibratedVoiceActivityDetector` must exclusively own each instance.
/// The unchecked conformance only bridges the opaque C allocation into that
/// actor-owned lifetime; callers must not invoke one classifier concurrently.
public final class WebRTCVoiceActivityClassifier: @unchecked Sendable, VoiceActivityClassifying {
    private let configuration: WebRTCVoiceActivityConfiguration
    private let nativeInstance: OpaquePointer
    private var noiseFloorRMS: Float
    private static let sampleRate = 16_000
    private static let frameSampleCount = 320

    public init(
        configuration: WebRTCVoiceActivityConfiguration = .sermon
    ) throws {
        try WebRTCConfigurationValidator.validate(configuration)
        guard let instance = fvad_new() else {
            throw WebRTCVoiceActivityClassifierError.allocationFailed
        }
        guard Self.configure(instance, using: configuration) else {
            fvad_free(instance)
            throw WebRTCVoiceActivityClassifierError.nativeConfigurationRejected
        }
        self.configuration = configuration
        nativeInstance = instance
        noiseFloorRMS = configuration.initialNoiseFloorRMS
    }

    deinit {
        fvad_free(nativeInstance)
    }

    public func isSpeech(
        _ samples: [Float],
        whileSpeaking: Bool
    ) -> Bool {
        do {
            return try classify(samples, whileSpeaking: whileSpeaking)
        } catch {
            preconditionFailure("VADCore violated the checked WebRTC frame invariant: \(error)")
        }
    }

    public func validateAnalysisWindow(
        sampleRate: Double,
        sampleCount: Int
    ) throws {
        guard abs(sampleRate - Double(Self.sampleRate)) <= 0.5 else {
            throw WebRTCVoiceActivityClassifierError.unsupportedSampleRate(
                expected: Self.sampleRate,
                actual: sampleRate
            )
        }
        guard sampleCount == Self.frameSampleCount else {
            throw WebRTCVoiceActivityClassifierError.invalidFrameLength(
                expected: Self.frameSampleCount,
                actual: sampleCount
            )
        }
    }

    /// Checks a 20 ms, 16 kHz mono frame and reports native failures.
    public func classify(
        _ samples: [Float],
        whileSpeaking _: Bool
    ) throws -> Bool {
        guard samples.count == Self.frameSampleCount else {
            throw WebRTCVoiceActivityClassifierError.invalidFrameLength(
                expected: Self.frameSampleCount,
                actual: samples.count
            )
        }
        guard samples.allSatisfy(\.isFinite) else {
            throw WebRTCVoiceActivityClassifierError.nonFiniteSamples
        }
        let rms = rootMeanSquare(of: samples)
        let energyThreshold = max(
            configuration.minimumEnergyRMS,
            noiseFloorRMS * configuration.energyThresholdMultiplier
        )
        let energyVoice = rms > energyThreshold
        if !energyVoice {
            adaptNoiseFloor(toward: rms)
        }
        let nativeVoice = try nativeDecision(for: samples)
        return nativeVoice || (energyVoice && rms > configuration.strongEnergyRMS)
    }

    public func reset() {
        fvad_reset(nativeInstance)
        precondition(
            Self.configure(nativeInstance, using: configuration),
            "libfvad rejected a previously validated reset configuration"
        )
        noiseFloorRMS = configuration.initialNoiseFloorRMS
    }

    private static func configure(
        _ instance: OpaquePointer,
        using configuration: WebRTCVoiceActivityConfiguration
    ) -> Bool {
        fvad_set_mode(instance, configuration.mode.rawValue) == 0
            && fvad_set_sample_rate(instance, Int32(Self.sampleRate)) == 0
    }

    private func nativeDecision(for samples: [Float]) throws -> Bool {
        let pulseCodeModulation = samples.map(Self.pcm16)
        let decision = pulseCodeModulation.withUnsafeBufferPointer { buffer in
            fvad_process(nativeInstance, buffer.baseAddress, buffer.count)
        }
        guard decision >= 0 else {
            throw WebRTCVoiceActivityClassifierError.nativeProcessingFailed
        }
        return decision == 1
    }

    private static func pcm16(_ sample: Float) -> Int16 {
        let scaled = max(-32_768, min(32_767, sample * 32_768))
        return Int16(scaled)
    }

    private func rootMeanSquare(of samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        let squareSum = samples.reduce(into: 0.0) { result, sample in
            let value = Double(sample)
            result += value * value
        }
        return Float((squareSum / Double(samples.count) + 1e-10).squareRoot())
    }

    private func adaptNoiseFloor(toward rms: Float) {
        let retained = configuration.noiseFloorRetention * noiseFloorRMS
        let observed = (1 - configuration.noiseFloorRetention) * rms
        noiseFloorRMS = retained + observed
    }
}

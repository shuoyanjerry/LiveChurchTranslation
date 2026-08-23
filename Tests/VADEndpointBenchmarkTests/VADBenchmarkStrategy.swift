import VADAPI
import VADCore
import VADWebRTC

enum VADBenchmarkStrategy: String, CaseIterable {
    case webrtcStable
    case webrtcMode3Stable
    case webrtcPause500
    case adaptiveEnergy

    func makeDetector() throws -> any VoiceActivityDetector {
        switch self {
        case .webrtcStable:
            return try CalibratedVoiceActivityDetector(
                classifier: try WebRTCVoiceActivityClassifier(),
                configuration: vadConfiguration
            )
        case .webrtcMode3Stable:
            return try CalibratedVoiceActivityDetector(
                classifier: try WebRTCVoiceActivityClassifier(
                    configuration: webRTCConfiguration
                ),
                configuration: vadConfiguration
            )
        case .webrtcPause500:
            return try CalibratedVoiceActivityDetector(
                classifier: try WebRTCVoiceActivityClassifier(),
                configuration: vadConfiguration
            )
        case .adaptiveEnergy:
            return try AdaptiveEnergyVoiceActivityDetector(configuration: vadConfiguration)
        }
    }

    static func makeSelectedShadowDetector() throws -> CalibratedVoiceActivityDetector {
        try CalibratedVoiceActivityDetector(
            classifier: try WebRTCVoiceActivityClassifier(configuration: .sermon),
            configuration: .sermon
        )
    }

    var metadata: VADStrategyMetadata {
        VADStrategyMetadata(
            classifier: self == .adaptiveEnergy ? "AdaptiveEnergy" : "libfvad+energy-rescue",
            classifierMode: self == .adaptiveEnergy ? nil : Int(webRTCConfiguration.mode.rawValue),
            libfvadRevision: self == .adaptiveEnergy
                ? nil
                : "532ab666c20d3cfda38bca63abbb0f152706c369",
            policy: vadConfiguration.benchmarkValues,
            classifierParameters: classifierParameters
        )
    }

    static func selected(from value: String?) throws -> [Self] {
        guard let value, !value.isEmpty else { return allCases }
        return try value.split(separator: ",").map { raw in
            let name = raw.trimmingCharacters(in: .whitespaces)
            guard let strategy = Self(rawValue: name) else {
                throw VADBenchmarkError.unknownStrategy(name)
            }
            return strategy
        }
    }

    private var vadConfiguration: VoiceActivityConfiguration {
        switch self {
        case .webrtcPause500:
            VoiceActivityConfiguration(preferredBoundarySilence: .milliseconds(500))
        default:
            .sermon
        }
    }

    private var webRTCConfiguration: WebRTCVoiceActivityConfiguration {
        self == .webrtcMode3Stable ? .init(mode: .veryAggressive) : .sermon
    }

    private var classifierParameters: [String: Double] {
        if self == .adaptiveEnergy {
            return [
                "initialNoiseFloorRMS": Double(vadConfiguration.initialNoiseFloorRMS),
                "minimumSpeechRMS": Double(vadConfiguration.minimumSpeechRMS),
                "noiseFloorSmoothing": Double(vadConfiguration.noiseFloorSmoothing),
                "speechThresholdMultiplier": Double(vadConfiguration.speechThresholdMultiplier),
            ]
        }
        let value = webRTCConfiguration
        return [
            "energyThresholdMultiplier": Double(value.energyThresholdMultiplier),
            "initialNoiseFloorRMS": Double(value.initialNoiseFloorRMS),
            "minimumEnergyRMS": Double(value.minimumEnergyRMS),
            "noiseFloorRetention": Double(value.noiseFloorRetention),
            "strongEnergyRMS": Double(value.strongEnergyRMS),
        ]
    }
}

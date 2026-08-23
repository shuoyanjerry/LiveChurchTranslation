import Foundation
import VADAPI
import VADWebRTC

struct V3SelectedVADConfigurationEvidence: Codable, Equatable, Sendable {
    let classifier: String
    let segmenter: String
    let durationNanoseconds: [String: Int64]
    let integerValues: [String: Int]
    let vadFloatBitPatterns: [String: UInt32]
    let webRTCMode: Int32
    let webRTCFloatBitPatterns: [String: UInt32]

    static func selected() -> Self {
        let vad = VoiceActivityConfiguration.sermon
        let webRTC = WebRTCVoiceActivityConfiguration.sermon
        return Self(
            classifier: "WebRTCVoiceActivityClassifier.sermon",
            segmenter: "VoiceActivityConfiguration.sermon",
            durationNanoseconds: durations(vad),
            integerValues: [
                "decisionSpeechVotes": vad.decisionSpeechVotes,
                "decisionWindowCount": vad.decisionWindowCount,
                "requiredSampleRateHz": Int(vad.requiredSampleRate),
            ],
            vadFloatBitPatterns: vadFloats(vad),
            webRTCMode: webRTC.mode.rawValue,
            webRTCFloatBitPatterns: webRTCFloats(webRTC)
        )
    }

    private static func durations(_ value: VoiceActivityConfiguration) -> [String: Int64] {
        [
            "analysisWindow": nanoseconds(value.analysisWindow),
            "maximumBoundaryGrace": nanoseconds(value.maximumBoundaryGrace),
            "minimumVoiced": nanoseconds(value.minimumVoiced),
            "postRoll": nanoseconds(value.postRoll),
            "preRoll": nanoseconds(value.preRoll),
            "preferredBoundarySilence": nanoseconds(value.preferredBoundarySilence),
            "preferredMaximumSegment": nanoseconds(value.preferredMaximumSegment),
            "shortTrailingSilence": nanoseconds(value.shortTrailingSilence),
            "shortUtterance": nanoseconds(value.shortUtterance),
            "softSplitAfter": nanoseconds(value.softSplitAfter),
            "softSplitSilence": nanoseconds(value.softSplitSilence),
            "speechStart": nanoseconds(value.speechStart),
            "trailingSilence": nanoseconds(value.trailingSilence),
        ]
    }

    private static func vadFloats(_ value: VoiceActivityConfiguration) -> [String: UInt32] {
        [
            "initialNoiseFloorRMS": value.initialNoiseFloorRMS.bitPattern,
            "minimumSpeechRMS": value.minimumSpeechRMS.bitPattern,
            "noiseFloorSmoothing": value.noiseFloorSmoothing.bitPattern,
            "speechThresholdMultiplier": value.speechThresholdMultiplier.bitPattern,
        ]
    }

    private static func webRTCFloats(
        _ value: WebRTCVoiceActivityConfiguration
    ) -> [String: UInt32] {
        [
            "energyThresholdMultiplier": value.energyThresholdMultiplier.bitPattern,
            "initialNoiseFloorRMS": value.initialNoiseFloorRMS.bitPattern,
            "minimumEnergyRMS": value.minimumEnergyRMS.bitPattern,
            "noiseFloorRetention": value.noiseFloorRetention.bitPattern,
            "strongEnergyRMS": value.strongEnergyRMS.bitPattern,
        ]
    }

    private static func nanoseconds(_ duration: Duration) -> Int64 {
        let value = duration.components
        return value.seconds * 1_000_000_000 + value.attoseconds / 1_000_000_000
    }
}

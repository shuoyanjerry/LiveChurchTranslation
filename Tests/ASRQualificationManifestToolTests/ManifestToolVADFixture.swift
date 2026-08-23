import Foundation

enum ManifestToolVADFixture {
    static func data(
        padding: Int = 0,
        pcmSHA256: String = ManifestToolTestAudio.pcmSHA256(),
        mutate: ((inout [String: Any]) -> Void)? = nil
    ) throws -> Data {
        var root: [String: Any] = [
            "schemaVersion": 1,
            "generatedAt": "2026-08-22T00:00:00Z",
            "environment": environment(),
            "caveats": ["fixture"],
            "strategies": [strategy(padding: padding, pcmSHA256: pcmSHA256)],
        ]
        mutate?(&root)
        return try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
    }

    private static func environment() -> [String: Any] {
        [
            "architecture": "arm64",
            "buildConfiguration": "debug",
            "hardwareModel": "fixture",
            "operatingSystem": "macOS",
            "physicalMemoryBytes": 1,
            "processorCount": 1,
            "repositoryHasUncommittedChanges": true,
            "repositoryRevision": "abc123",
            "swiftVersion": "Swift 6.1",
        ]
    }

    private static func strategy(padding: Int, pcmSHA256: String) -> [String: Any] {
        let file = fileReport(padding: padding, pcmSHA256: pcmSHA256)
        return [
            "strategy": "webrtcStable",
            "configuration": configuration(),
            "files": [file],
            "aggregate": metrics(audioSeconds: 0.00025),
            "residentBytesAtCompletion": NSNull(),
            "processPeakResidentBytesAtCompletion": NSNull(),
        ]
    }

    private static func fileReport(padding: Int, pcmSHA256: String) -> [String: Any] {
        let wav = ManifestToolTestAudio.wav()
        return [
            "corpusID": "sermon-01",
            "fileName": "clip-a.wav",
            "sha256": ManifestToolTestAudio.sha256(wav),
            "byteCount": wav.count,
            "sampleRateHz": 16_000,
            "totalSamples": 4,
            "audioSeconds": 0.00025,
            "detectorProcessingSeconds": 0.001,
            "replayWallSeconds": 0.002,
            "boundaries": [boundary(padding: padding, pcmSHA256: pcmSHA256)],
            "metrics": metrics(audioSeconds: 0.00025),
        ]
    }

    private static func boundary(padding: Int, pcmSHA256: String) -> [String: Any] {
        [
            "sequenceNumber": 1,
            "startSample": 0,
            "endSample": 4,
            "validSampleCount": 4,
            "pcmSHA256": pcmSHA256,
            "startedAtSeconds": 0,
            "endedAtSeconds": 0.00025,
            "durationSeconds": 0.00025,
            "reason": "endOfStream",
            "signedEmissionOffsetFromRetainedAudioSeconds": 0,
            "emissionLagAfterRetainedAudioSeconds": NSNull(),
            "syntheticPaddingSamplesAtEmission": padding,
        ]
    }

    private static func metrics(audioSeconds: Double) -> [String: Any] {
        [
            "audioSeconds": audioSeconds,
            "detectorProcessingSeconds": 0.001,
            "detectorRTF": 4,
            "segmentCount": 1,
            "underTwoSecondsCount": 1,
            "underTwoSecondsRate": 1,
            "forcedHardCutProxyCount": 0,
            "forcedHardCutProxyRate": 0,
            "reasonCounts": ["endOfStream": 1],
            "segmentDurationSeconds": percentiles(0.00025),
            "emissionLagAfterRetainedAudioSeconds": percentiles(nil),
        ]
    }

    private static func percentiles(_ value: Double?) -> [String: Any] {
        let encoded: Any = value ?? NSNull()
        return ["p50": encoded, "p95": encoded, "p99": encoded]
    }

    private static func configuration() -> [String: Any] {
        [
            "classifier": "libfvad+energy-rescue",
            "classifierMode": 2,
            "classifierParameters": classifierParameters(),
            "libfvadRevision": "532ab666",
            "policy": policy(),
        ]
    }

    private static func classifierParameters() -> [String: Any] {
        [
            "energyThresholdMultiplier": 3.2,
            "initialNoiseFloorRMS": 0.0025,
            "minimumEnergyRMS": 0.006,
            "noiseFloorRetention": 0.995,
            "strongEnergyRMS": 0.018,
        ]
    }
}

struct VADReport: Decodable {
    let schemaVersion: Int
    let generatedAt: String
    let environment: VADEnvironment
    let caveats: [String]
    let strategies: [VADStrategy]
}

struct VADEnvironment: Decodable {
    let architecture: String
    let buildConfiguration: String
    let hardwareModel: String
    let operatingSystem: String
    let physicalMemoryBytes: UInt64
    let processorCount: Int
    let repositoryHasUncommittedChanges: Bool
    let repositoryRevision: String
    let swiftVersion: String
}

struct VADStrategy: Decodable {
    let strategy: String
    let configuration: VADConfiguration
    let files: [VADFile]
    let aggregate: VADMetrics
    let residentBytesAtCompletion: UInt64?
    let processPeakResidentBytesAtCompletion: UInt64?
}

struct VADFile: Decodable {
    let corpusID: String
    let fileName: String
    let sha256: String
    let byteCount: Int64
    let sampleRateHz: Int
    let totalSamples: Int
    let audioSeconds: Double
    let detectorProcessingSeconds: Double
    let replayWallSeconds: Double
    let boundaries: [VADBoundary]
    let metrics: VADMetrics
}

struct VADBoundary: Decodable {
    let sequenceNumber: UInt64
    let startSample: Int
    let endSample: Int
    let validSampleCount: Int
    let pcmSHA256: String
    let startedAtSeconds: Double
    let endedAtSeconds: Double
    let durationSeconds: Double
    let reason: String
    let signedEmissionOffsetSeconds: Double
    let emissionLagAfterRetainedAudioSeconds: Double?
    let syntheticPaddingSamplesAtEmission: Int

    enum CodingKeys: String, CodingKey {
        case sequenceNumber, startSample, endSample, validSampleCount, pcmSHA256
        case startedAtSeconds, endedAtSeconds, durationSeconds, reason
        case signedEmissionOffsetSeconds = "signedEmissionOffsetFromRetainedAudioSeconds"
        case emissionLagAfterRetainedAudioSeconds, syntheticPaddingSamplesAtEmission
    }
}

struct VADMetrics: Decodable {
    let audioSeconds: Double
    let detectorProcessingSeconds: Double
    let detectorRTF: Double
    let segmentCount: Int
    let underTwoSecondsCount: Int
    let underTwoSecondsRate: Double
    let forcedHardCutProxyCount: Int
    let forcedHardCutProxyRate: Double
    let reasonCounts: [String: Int]
    let segmentDurationSeconds: VADPercentiles
    let emissionLagAfterRetainedAudioSeconds: VADPercentiles
}

struct VADPercentiles: Decodable {
    let p50: Double?
    let p95: Double?
    let p99: Double?
}

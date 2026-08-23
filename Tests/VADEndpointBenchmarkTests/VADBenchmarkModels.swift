import Foundation

struct VADBenchmarkDocument: Encodable {
    let schemaVersion = 1
    let generatedAt: Date
    let environment: VADBenchmarkEnvironmentMetadata
    let caveats: [String]
    let strategies: [VADStrategyReport]
}

struct VADStrategyReport: Encodable {
    let strategy: String
    let configuration: VADStrategyMetadata
    let files: [VADFileReport]
    let aggregate: VADMetricsReport
    let residentBytesAtCompletion: UInt64?
    let processPeakResidentBytesAtCompletion: UInt64?
}

struct VADFileReport: Encodable {
    let corpusID: String
    let fileName: String
    let sha256: String
    let byteCount: Int64
    let sampleRateHz: Int
    let totalSamples: Int64
    let audioSeconds: Double
    let detectorProcessingSeconds: Double
    let replayWallSeconds: Double
    let boundaries: [VADBoundaryRecord]
    let metrics: VADMetricsReport

    init(
        corpusID: String,
        fileName: String,
        sha256: String,
        byteCount: Int64,
        sampleRateHz: Int,
        totalSamples: Int64,
        audioSeconds: Double,
        detectorProcessingSeconds: Double,
        replayWallSeconds: Double,
        boundaries: [VADBoundaryRecord]
    ) {
        self.corpusID = corpusID
        self.fileName = fileName
        self.sha256 = sha256
        self.byteCount = byteCount
        self.sampleRateHz = sampleRateHz
        self.totalSamples = totalSamples
        self.audioSeconds = audioSeconds
        self.detectorProcessingSeconds = detectorProcessingSeconds
        self.replayWallSeconds = replayWallSeconds
        self.boundaries = boundaries
        metrics = VADMetricsReport(
            audioSeconds: audioSeconds,
            processingSeconds: detectorProcessingSeconds,
            boundaries: boundaries
        )
    }
}

struct VADBoundaryRecord: Encodable {
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

    private enum CodingKeys: String, CodingKey {
        case sequenceNumber
        case startSample
        case endSample
        case validSampleCount
        case pcmSHA256
        case startedAtSeconds
        case endedAtSeconds
        case durationSeconds
        case reason
        case signedEmissionOffsetSeconds = "signedEmissionOffsetFromRetainedAudioSeconds"
        case emissionLagAfterRetainedAudioSeconds
        case syntheticPaddingSamplesAtEmission
    }
}

struct VADMetricsReport: Encodable {
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

    init(files: [VADFileReport]) {
        let boundaries = files.flatMap(\.boundaries)
        self.init(
            audioSeconds: files.reduce(0) { $0 + $1.audioSeconds },
            processingSeconds: files.reduce(0) { $0 + $1.detectorProcessingSeconds },
            boundaries: boundaries
        )
    }

    init(
        audioSeconds: Double,
        processingSeconds: Double,
        boundaries: [VADBoundaryRecord]
    ) {
        let metrics = VADMetrics(
            audioSeconds: audioSeconds,
            processingSeconds: processingSeconds,
            boundaries: boundaries
        )
        self.audioSeconds = metrics.audioSeconds
        detectorProcessingSeconds = metrics.processingSeconds
        detectorRTF = metrics.rtf
        segmentCount = metrics.segmentCount
        underTwoSecondsCount = metrics.underTwoSecondsCount
        underTwoSecondsRate = metrics.underTwoSecondsRate
        forcedHardCutProxyCount = metrics.forcedHardCutProxyCount
        forcedHardCutProxyRate = metrics.forcedHardCutProxyRate
        reasonCounts = metrics.reasonCounts
        segmentDurationSeconds = metrics.durationPercentiles
        emissionLagAfterRetainedAudioSeconds = metrics.emissionLagPercentiles
    }
}

struct VADPercentiles: Encodable {
    let p50: Double?
    let p95: Double?
    let p99: Double?
}

extension VADInputShape {
    static func validateFile(_ value: Any, path: String) throws {
        let object = try StrictJSONShape.object(value, path: path)
        try StrictJSONShape.exact(
            object,
            keys: [
                "corpusID", "fileName", "sha256", "byteCount", "sampleRateHz",
                "totalSamples", "audioSeconds", "detectorProcessingSeconds",
                "replayWallSeconds", "boundaries", "metrics",
            ],
            path: path
        )
        try validateMetrics(object["metrics"], path: "\(path).metrics")
        let boundaries = try StrictJSONShape.array(
            object["boundaries"],
            path: "\(path).boundaries"
        )
        for (index, boundary) in boundaries.enumerated() {
            try validateBoundary(boundary, path: "\(path).boundaries[\(index)]")
        }
    }

    static func validateBoundary(_ value: Any, path: String) throws {
        let object = try StrictJSONShape.object(value, path: path)
        try StrictJSONShape.exact(
            object,
            keys: [
                "sequenceNumber", "startSample", "endSample", "validSampleCount",
                "pcmSHA256", "startedAtSeconds", "endedAtSeconds", "durationSeconds",
                "reason", "signedEmissionOffsetFromRetainedAudioSeconds",
                "emissionLagAfterRetainedAudioSeconds", "syntheticPaddingSamplesAtEmission",
            ],
            path: path
        )
    }

    static func validateMetrics(_ value: Any?, path: String) throws {
        let object = try StrictJSONShape.object(value, path: path)
        try StrictJSONShape.exact(
            object,
            keys: [
                "audioSeconds", "detectorProcessingSeconds", "detectorRTF", "segmentCount",
                "underTwoSecondsCount", "underTwoSecondsRate", "forcedHardCutProxyCount",
                "forcedHardCutProxyRate", "reasonCounts", "segmentDurationSeconds",
                "emissionLagAfterRetainedAudioSeconds",
            ],
            path: path
        )
        _ = try StrictJSONShape.object(object["reasonCounts"], path: "\(path).reasonCounts")
        try validatePercentiles(object["segmentDurationSeconds"], path: "\(path).segmentDurationSeconds")
        try validatePercentiles(
            object["emissionLagAfterRetainedAudioSeconds"],
            path: "\(path).emissionLagAfterRetainedAudioSeconds"
        )
    }

    static func validatePercentiles(_ value: Any?, path: String) throws {
        let object = try StrictJSONShape.object(value, path: path)
        try StrictJSONShape.exact(object, keys: ["p50", "p95", "p99"], path: path)
    }
}

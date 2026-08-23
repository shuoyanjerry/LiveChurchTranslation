import Foundation

enum VADInputShape {
    static func validate(_ data: Data) throws {
        let root = try StrictJSONShape.rootObject(data, source: "vad")
        try StrictJSONShape.exact(
            root,
            keys: ["schemaVersion", "generatedAt", "environment", "caveats", "strategies"],
            path: "vad"
        )
        try validateEnvironment(root["environment"])
        let strategies = try StrictJSONShape.array(root["strategies"], path: "vad.strategies")
        for (index, value) in strategies.enumerated() {
            try validateStrategy(value, path: "vad.strategies[\(index)]")
        }
    }

    private static func validateEnvironment(_ value: Any?) throws {
        let path = "vad.environment"
        let object = try StrictJSONShape.object(value, path: path)
        try StrictJSONShape.exact(
            object,
            keys: [
                "architecture", "buildConfiguration", "hardwareModel", "operatingSystem",
                "physicalMemoryBytes", "processorCount", "repositoryHasUncommittedChanges",
                "repositoryRevision", "swiftVersion",
            ],
            path: path
        )
    }

    private static func validateStrategy(_ value: Any, path: String) throws {
        let object = try StrictJSONShape.object(value, path: path)
        try StrictJSONShape.exact(
            object,
            keys: [
                "strategy", "configuration", "files", "aggregate",
                "residentBytesAtCompletion", "processPeakResidentBytesAtCompletion",
            ],
            path: path
        )
        try validateConfiguration(object["configuration"], path: "\(path).configuration")
        try validateMetrics(object["aggregate"], path: "\(path).aggregate")
        let files = try StrictJSONShape.array(object["files"], path: "\(path).files")
        for (index, file) in files.enumerated() {
            try validateFile(file, path: "\(path).files[\(index)]")
        }
    }

    private static func validateConfiguration(_ value: Any?, path: String) throws {
        let object = try StrictJSONShape.object(value, path: path)
        try StrictJSONShape.exact(
            object,
            keys: [
                "classifier", "classifierMode", "classifierParameters",
                "libfvadRevision", "policy",
            ],
            path: path
        )
        try validateClassifier(object["classifierParameters"], path: "\(path).classifierParameters")
        try validatePolicy(object["policy"], path: "\(path).policy")
    }

    private static func validateClassifier(_ value: Any?, path: String) throws {
        let object = try StrictJSONShape.object(value, path: path)
        try StrictJSONShape.exact(
            object,
            keys: [
                "energyThresholdMultiplier", "initialNoiseFloorRMS", "minimumEnergyRMS",
                "noiseFloorRetention", "strongEnergyRMS",
            ],
            path: path
        )
    }

    private static func validatePolicy(_ value: Any?, path: String) throws {
        let object = try StrictJSONShape.object(value, path: path)
        try StrictJSONShape.exact(
            object,
            keys: [
                "analysisWindowMs", "decisionSpeechVotes", "decisionWindowCount",
                "maximumBoundaryGraceMs", "minimumVoicedMs", "postRollMs", "preRollMs",
                "preferredBoundarySilenceMs", "preferredMaximumSegmentMs",
                "requiredSampleRateHz", "shortTrailingSilenceMs", "shortUtteranceMs",
                "softSplitAfterMs", "softSplitSilenceMs", "speechStartMs", "trailingSilenceMs",
            ],
            path: path
        )
    }
}

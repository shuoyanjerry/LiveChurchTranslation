import Foundation
@testable import TranslationHyMT2

enum HyMT2NegationShadowQ4Settings {
    static let seed = 42
    static let temperature = 0.0
    static let topP = 0.6
    static let topK = 20
    static let repetitionPenalty = 1.05
    static let threadCount = 4
    static let contextSize = 4_096
    static let maximumTokens = 768
    static let gpuLayerCount = 99
    static let requestTimeout: TimeInterval = 45
    static let expectedModelSHA256 =
        "dc5f44fcf1fa496ee7ad725982c0c8c553a4de00259b53af84c4b89fb0c06699"
    static let expectedHelperSHA256 =
        "d0878274b8d6bd3c8ea26a78eb66cd1ffd943d007c62b9dff31c8aa99922d713"

    static var runtimeConfiguration: HyMT2Configuration {
        HyMT2Configuration(
            startupTimeout: .seconds(60),
            healthPollInterval: .milliseconds(150),
            requestTimeout: requestTimeout,
            contextSize: contextSize,
            maximumOutputTokens: maximumTokens,
            threadCount: threadCount,
            gpuLayerCount: gpuLayerCount
        )
    }
}

enum HyMT2NegationShadowQ4EnvironmentError: Error, Equatable {
    case hashMismatch(String)
    case invalidReportLocation
    case missingEnvironment(String)
    case unavailableArtifact(String)
}

struct HyMT2NegationShadowQ4Environment {
    let modelURL: URL
    let helperURL: URL
    let reportURL: URL
    let modelSHA256: String
    let helperSHA256: String

    static func load(_ values: [String: String]) throws -> HyMT2NegationShadowQ4Environment {
        let modelLocation = try required("HYMT_MODEL_DIR", in: values)
        let helperPath = try required("HYMT_LLAMA_SERVER", in: values)
        let reportPath = try required("HYMT_NEGATION_SHADOW_REPORT", in: values)
        let modelURL = try HyMT2ModelResolver.resolve(
            at: URL(fileURLWithPath: modelLocation),
            expectedFilename: HyMT2Configuration().modelFilename
        )
        let helperURL = URL(fileURLWithPath: helperPath).standardizedFileURL
        guard FileManager.default.isExecutableFile(atPath: helperURL.path) else {
            throw HyMT2NegationShadowQ4EnvironmentError.unavailableArtifact("helper")
        }
        let reportURL = try validatedReportURL(reportPath)
        let modelHash = try HyMT2NegationShadowFileHasher.sha256(modelURL)
        let helperHash = try HyMT2NegationShadowFileHasher.sha256(helperURL)
        try requireHash(modelHash, expected: HyMT2NegationShadowQ4Settings.expectedModelSHA256)
        try requireHash(helperHash, expected: HyMT2NegationShadowQ4Settings.expectedHelperSHA256)
        return HyMT2NegationShadowQ4Environment(
            modelURL: modelURL,
            helperURL: helperURL,
            reportURL: reportURL,
            modelSHA256: modelHash,
            helperSHA256: helperHash
        )
    }

    private static func required(
        _ key: String,
        in values: [String: String]
    ) throws -> String {
        guard let value = values[key], !value.isEmpty else {
            throw HyMT2NegationShadowQ4EnvironmentError.missingEnvironment(key)
        }
        return value
    }

    private static func validatedReportURL(_ path: String) throws -> URL {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(".artifacts", isDirectory: true)
            .resolvingSymlinksInPath()
        let candidate = URL(fileURLWithPath: path).standardizedFileURL
        let parent = candidate.deletingLastPathComponent().resolvingSymlinksInPath()
        guard candidate.pathExtension == "json",
            parent.path == root.path || parent.path.hasPrefix(root.path + "/")
        else {
            throw HyMT2NegationShadowQ4EnvironmentError.invalidReportLocation
        }
        return candidate
    }

    private static func requireHash(_ actual: String, expected: String) throws {
        guard actual == expected else {
            throw HyMT2NegationShadowQ4EnvironmentError.hashMismatch("sha256")
        }
    }
}

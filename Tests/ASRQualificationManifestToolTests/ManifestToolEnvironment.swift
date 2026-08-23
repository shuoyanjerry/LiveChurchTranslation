import Foundation

struct ManifestToolInputs: Equatable, Sendable {
    let vadReportURL: URL
    let corpusManifestURL: URL
    let referenceManifestURL: URL
    let wavDirectoryURL: URL
    let outputURL: URL
}

enum ManifestToolEnvironment {
    static let keys = [
        "ASR_QUALIFICATION_VAD_REPORT",
        "ASR_QUALIFICATION_CORPUS_MANIFEST",
        "ASR_QUALIFICATION_REFERENCE_MANIFEST",
        "ASR_QUALIFICATION_WAV_DIR",
        "ASR_QUALIFICATION_OUTPUT",
    ]

    static func inputs(from environment: [String: String]) throws -> ManifestToolInputs? {
        let supplied = keys.filter { value(for: $0, in: environment) != nil }
        guard !supplied.isEmpty else { return nil }
        let missing = keys.filter { value(for: $0, in: environment) == nil }
        guard missing.isEmpty else {
            throw ManifestToolError.incompleteEnvironment(missing: missing)
        }
        return ManifestToolInputs(
            vadReportURL: url(keys[0], environment),
            corpusManifestURL: url(keys[1], environment),
            referenceManifestURL: url(keys[2], environment),
            wavDirectoryURL: url(keys[3], environment),
            outputURL: url(keys[4], environment)
        )
    }

    private static func value(
        for key: String,
        in environment: [String: String]
    ) -> String? {
        guard let value = environment[key], !value.allSatisfy(\.isWhitespace) else {
            return nil
        }
        return value
    }

    private static func url(_ key: String, _ environment: [String: String]) -> URL {
        URL(fileURLWithPath: value(for: key, in: environment) ?? "")
    }
}

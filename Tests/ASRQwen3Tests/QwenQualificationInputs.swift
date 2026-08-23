import Foundation

struct QwenQualificationInputs: Equatable {
    let modelDirectory: URL
    let manifestURL: URL
    let referenceManifestURL: URL
    let wavDirectory: URL
    let reportURL: URL
    let profile: QwenQualificationProfile

    init(environment: [String: String]) throws {
        try Self.rejectUnsupportedOverrides(in: environment)
        profile = try QwenQualificationProfile(
            environmentValue: environment["QWEN_QUALIFICATION_PROFILE"]
        )
        modelDirectory = try Self.url(for: "QWEN_MODEL_DIR", in: environment)
        manifestURL = try Self.url(
            for: "MANDARIN_ASR_QUALIFICATION_MANIFEST",
            in: environment
        )
        referenceManifestURL = try Self.url(
            for: "MANDARIN_ASR_REFERENCE_MANIFEST",
            in: environment
        )
        wavDirectory = try Self.url(for: "MANDARIN_ASR_WAV_DIR", in: environment)
        reportURL = try Self.url(for: "QWEN_ASR_REPORT", in: environment)
    }

    private static func rejectUnsupportedOverrides(
        in environment: [String: String]
    ) throws {
        let unsupported = [
            "QWEN_INFERENCE_THREADS",
            "MANDARIN_ASR_MAX_CLIPS",
            "MANDARIN_ASR_PROMPT",
        ]
        if let key = unsupported.first(where: { environment[$0] != nil }) {
            throw QwenQualificationInputError.unsupportedOverride(key)
        }
    }

    private static func url(
        for key: String,
        in environment: [String: String]
    ) throws -> URL {
        guard let value = environment[key], !value.isEmpty else {
            throw QwenQualificationInputError.missingEnvironment(key)
        }
        return URL(fileURLWithPath: value).standardizedFileURL
    }
}

enum QwenQualificationInputError: Error, Equatable {
    case missingEnvironment(String)
    case unsupportedOverride(String)
}

extension Duration {
    var qwenQualificationSeconds: Double {
        let values = components
        return Double(values.seconds) + Double(values.attoseconds) / 1e18
    }
}

import Foundation

struct FunQualificationInputs: Equatable {
    let modelDirectory: URL
    let manifestURL: URL
    let referenceManifestURL: URL
    let wavDirectory: URL
    let reportURL: URL

    init(environment: [String: String]) throws {
        try Self.rejectOverrides(in: environment)
        modelDirectory = try Self.url(for: "FUNASR_MODEL_DIR", in: environment)
        manifestURL = try Self.url(
            for: "MANDARIN_ASR_QUALIFICATION_MANIFEST",
            in: environment
        )
        referenceManifestURL = try Self.url(
            for: "MANDARIN_ASR_REFERENCE_MANIFEST",
            in: environment
        )
        wavDirectory = try Self.url(for: "MANDARIN_ASR_WAV_DIR", in: environment)
        reportURL = try Self.url(for: "FUNASR_ASR_REPORT", in: environment)
    }

    private static func rejectOverrides(in environment: [String: String]) throws {
        let unsupported = [
            "FUNASR_INFERENCE_THREADS",
            "MANDARIN_ASR_MAX_CLIPS",
            "MANDARIN_ASR_PROMPT",
        ]
        if let key = unsupported.first(where: { environment[$0] != nil }) {
            throw FunQualificationInputError.unsupportedOverride(key)
        }
    }

    private static func url(
        for key: String,
        in environment: [String: String]
    ) throws -> URL {
        guard let value = environment[key], !value.isEmpty else {
            throw FunQualificationInputError.missingEnvironment(key)
        }
        return URL(fileURLWithPath: value).standardizedFileURL
    }
}

enum FunQualificationInputError: Error, Equatable {
    case missingEnvironment(String)
    case unsupportedOverride(String)
}

extension Duration {
    var funQualificationSeconds: Double {
        let values = components
        return Double(values.seconds) + Double(values.attoseconds) / 1e18
    }
}

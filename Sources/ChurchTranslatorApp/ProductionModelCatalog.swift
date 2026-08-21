import Foundation
import ModelDownloadHTTP
import ModelRuntimeAPI

enum ProductionModelCatalog {
    static let qwenDescriptor = ModelDescriptor(
        id: ModelID(rawValue: "qwen3-asr-0.6b-int8-2026-03-25"),
        displayName: "Qwen3-ASR 0.6B INT8",
        version: "68818b2313fe77bd06f6a7c5068ff3ef59d02b8a",
        expectedBytes: 987_015_347,
        sha256: nil,
        license: "Apache-2.0"
    )

    static let translationDescriptor = ModelDescriptor(
        id: ModelID(rawValue: "hy-mt2-1.8b-q4-k-m"),
        displayName: "Hy-MT2 1.8B Q4_K_M",
        version: "1cd5208700acedef4ef93019b6cfc148b8522d45",
        expectedBytes: 1_133_080_448,
        sha256: "dc5f44fcf1fa496ee7ad725982c0c8c553a4de00259b53af84c4b89fb0c06699",
        license: "Apache-2.0"
    )

    static func manifests() throws -> [ModelDownloadManifest] {
        [try qwenManifest(), try translationManifest()]
    }

    private static func translationManifest() throws -> ModelDownloadManifest {
        let filename = "Hy-MT2-1.8B-Q4_K_M.gguf"
        let root = "https://huggingface.co/tencent/Hy-MT2-1.8B-GGUF/resolve/"
        let artifact = try ModelArtifactManifest(
            remoteURL: requiredURL(root + translationDescriptor.version + "/" + filename),
            relativePath: filename,
            expectedBytes: translationDescriptor.expectedBytes,
            sha256: translationDescriptor.sha256 ?? ""
        )
        return try ModelDownloadManifest(
            descriptor: translationDescriptor,
            installDirectoryName: translationDescriptor.id.rawValue,
            artifacts: [artifact],
            result: .directory
        )
    }

    static func requiredURL(_ value: String) throws -> URL {
        guard let url = URL(string: value) else { throw CocoaError(.fileReadInvalidFileName) }
        return url
    }
}

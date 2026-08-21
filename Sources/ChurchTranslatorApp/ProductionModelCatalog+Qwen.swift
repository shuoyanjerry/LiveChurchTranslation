import Foundation
import ModelDownloadHTTP

extension ProductionModelCatalog {
    static func qwenManifest() throws -> ModelDownloadManifest {
        let root =
            "https://huggingface.co/csukuangfj2/"
            + "sherpa-onnx-qwen3-asr-0.6B-int8-2026-03-25/resolve/"
            + qwenDescriptor.version + "/"
        let artifacts = try qwenArtifacts.map { try $0.manifest(relativeTo: root) }
        return try ModelDownloadManifest(
            descriptor: qwenDescriptor,
            installDirectoryName: qwenDescriptor.id.rawValue,
            artifacts: artifacts,
            result: .directory
        )
    }

    private static let qwenArtifacts = [
        ProductionModelArtifact(
            path: "conv_frontend.onnx",
            expectedBytes: 44_148_281,
            sha256: "d22dc4423e0940e49884e903d2ea2f7e5567c14fc1aed97e4e26d6b8f208ef9e"
        ),
        ProductionModelArtifact(
            path: "encoder.int8.onnx",
            expectedBytes: 182_491_662,
            sha256: "60748d3e6744a57c9c91e1b17424a6c2990567e8adceb0783940c03ed98fa9d9"
        ),
        ProductionModelArtifact(
            path: "decoder.int8.onnx",
            expectedBytes: 755_914_231,
            sha256: "4f6885be5959ae26af3089d38ee7972c5fafbeeb1cf8d5e76eab6d8b61ca5771"
        ),
        ProductionModelArtifact(
            path: "tokenizer/merges.txt",
            expectedBytes: 1_671_853,
            sha256: "8831e4f1a044471340f7c0a83d7bd71306a5b867e95fd870f74d0c5308a904d5"
        ),
        ProductionModelArtifact(
            path: "tokenizer/tokenizer_config.json",
            expectedBytes: 12_487,
            sha256: "4942d005604266809309cabc9f4e9cb89ce855d59b14681fdc0e1cc62ea26c4c"
        ),
        ProductionModelArtifact(
            path: "tokenizer/vocab.json",
            expectedBytes: 2_776_833,
            sha256: "ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910"
        ),
    ]
}

private struct ProductionModelArtifact {
    let path: String
    let expectedBytes: Int64
    let sha256: String

    func manifest(relativeTo root: String) throws -> ModelArtifactManifest {
        try ModelArtifactManifest(
            remoteURL: ProductionModelCatalog.requiredURL(root + path),
            relativePath: path,
            expectedBytes: expectedBytes,
            sha256: sha256
        )
    }
}

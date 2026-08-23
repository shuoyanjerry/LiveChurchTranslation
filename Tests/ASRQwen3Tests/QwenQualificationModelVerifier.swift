import Foundation

struct QwenQualificationModelArtifact: Equatable, Sendable {
    let relativePath: String
    let expectedBytes: Int64
    let sha256: String
}

struct QwenQualificationModelVerifier: Sendable {
    private let artifacts: [QwenQualificationModelArtifact]

    init(artifacts: [QwenQualificationModelArtifact] = Self.productionArtifacts) {
        self.artifacts = artifacts
    }

    func verify(directory: URL) throws {
        for artifact in artifacts {
            try verify(artifact, in: directory)
        }
    }

    private func verify(
        _ artifact: QwenQualificationModelArtifact,
        in directory: URL
    ) throws {
        let url = directory.appending(path: artifact.relativePath)
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            throw QwenQualificationModelVerificationError.missingFile(artifact.relativePath)
        }
        guard Int64(size) == artifact.expectedBytes else {
            throw QwenQualificationModelVerificationError.byteCountMismatch(
                artifact.relativePath
            )
        }
        guard try QwenQualificationHashing.sha256(contentsOf: url) == artifact.sha256 else {
            throw QwenQualificationModelVerificationError.sha256Mismatch(artifact.relativePath)
        }
    }

    static let productionArtifacts = [
        artifact(
            "conv_frontend.onnx", 44_148_281,
            "d22dc4423e0940e49884e903d2ea2f7e5567c14fc1aed97e4e26d6b8f208ef9e"),
        artifact(
            "encoder.int8.onnx", 182_491_662,
            "60748d3e6744a57c9c91e1b17424a6c2990567e8adceb0783940c03ed98fa9d9"),
        artifact(
            "decoder.int8.onnx", 755_914_231,
            "4f6885be5959ae26af3089d38ee7972c5fafbeeb1cf8d5e76eab6d8b61ca5771"),
        artifact(
            "tokenizer/merges.txt", 1_671_853,
            "8831e4f1a044471340f7c0a83d7bd71306a5b867e95fd870f74d0c5308a904d5"),
        artifact(
            "tokenizer/tokenizer_config.json", 12_487,
            "4942d005604266809309cabc9f4e9cb89ce855d59b14681fdc0e1cc62ea26c4c"),
        artifact(
            "tokenizer/vocab.json", 2_776_833,
            "ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910"),
    ]

    private static func artifact(
        _ relativePath: String,
        _ bytes: Int64,
        _ sha256: String
    ) -> QwenQualificationModelArtifact {
        QwenQualificationModelArtifact(
            relativePath: relativePath,
            expectedBytes: bytes,
            sha256: sha256
        )
    }
}

enum QwenQualificationModelVerificationError: Error, Equatable {
    case missingFile(String)
    case byteCountMismatch(String)
    case sha256Mismatch(String)
}

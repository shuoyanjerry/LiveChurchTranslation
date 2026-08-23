struct FunASRNanoModelArtifact: Equatable, Sendable {
    let relativePath: String
    let byteCount: Int
    let sha256: String
}

extension FunASRNanoModelArtifact {
    static let required: [Self] = [
        .init(
            relativePath: "encoder_adaptor.int8.onnx",
            byteCount: 238_277_200,
            sha256: "d0246c823f2c34133ae0efee395d8a189c8f92643e3432f866939ee34d34492c"
        ),
        .init(
            relativePath: "embedding.int8.onnx",
            byteCount: 155_583_106,
            sha256: "a05d2816e284fcca29a5dccb2c14b9edeb638fd983a84cd4a447248889b6a408"
        ),
        .init(
            relativePath: "llm.int8.onnx",
            byteCount: 600_339_316,
            sha256: "7f0c5a508b41474b1b1ec1cdbdefafd2cf8b3642c6915a0a425265b7b7d2c960"
        ),
        .init(
            relativePath: "Qwen3-0.6B/merges.txt",
            byteCount: 1_671_853,
            sha256: "8831e4f1a044471340f7c0a83d7bd71306a5b867e95fd870f74d0c5308a904d5"
        ),
        .init(
            relativePath: "Qwen3-0.6B/tokenizer.json",
            byteCount: 11_422_654,
            sha256: "aeb13307a71acd8fe81861d94ad54ab689df773318809eed3cbe794b4492dae4"
        ),
        .init(
            relativePath: "Qwen3-0.6B/vocab.json",
            byteCount: 2_776_833,
            sha256: "ca10d7e9fb3ed18575dd1e277a2579c16d108e32f27439684afa0e10b1440910"
        ),
    ]
}

import Foundation

enum ScriptureProductionModelIdentity {
    static func verify(
        configuration: ScriptureModelQualificationConfiguration
    ) throws -> [ScriptureQualificationProviderIdentity] {
        try verifyQwen(at: configuration.qwenModelDirectory)
        let hyMTModel = try hyMTModelURL(at: configuration.hyMTModelLocation)
        try require(
            hyMTModel,
            expectedBytes: hyMTModelBytes,
            expectedSHA256: hyMTModelSHA256,
            label: "hy-mt2-model"
        )
        let runtime = try ScriptureLlamaRuntimeIdentity.verify(
            helperURL: configuration.hyMTHelperURL,
            workspaceRoot: configuration.workspaceRoot
        )
        return identities(runtime: runtime)
    }

    private static func verifyQwen(at directory: URL) throws {
        do {
            try QwenQualificationModelVerifier().verify(directory: directory)
        } catch {
            throw ScriptureModelQualificationError.modelIdentityMismatch("qwen3-asr")
        }
    }

    private static func identities(
        runtime: ScriptureLlamaRuntimeSnapshot
    ) -> [ScriptureQualificationProviderIdentity] {
        [
            ScriptureQualificationProviderIdentity(
                identifier: "qwen.qwen3-asr.sherpa-onnx",
                modelRevision: QwenQualificationConfiguration.modelRevision,
                modelSHA256: qwenArtifactSetSHA256,
                runtimeRevision: QwenQualificationConfiguration.runtimeRevision,
                runtimeSHA256: nil,
                runtimeBundleSHA256: nil
            ),
            ScriptureQualificationProviderIdentity(
                identifier: "tencent.hy-mt2-1.8b.gguf.llama-cpp",
                modelRevision: hyMTModelRevision,
                modelSHA256: hyMTModelSHA256,
                runtimeRevision: hyMTRuntimeRevision,
                runtimeSHA256: runtime.helperSHA256,
                runtimeBundleSHA256: runtime.bundleSHA256
            ),
        ]
    }

    private static func hyMTModelURL(at location: URL) throws -> URL {
        let values = try? location.resourceValues(forKeys: [.isDirectoryKey])
        guard let isDirectory = values?.isDirectory else {
            throw ScriptureModelQualificationError.modelIdentityMismatch("hy-mt2-model")
        }
        return isDirectory
            ? location.appendingPathComponent("Hy-MT2-1.8B-Q4_K_M.gguf") : location
    }

    private static func require(
        _ url: URL,
        expectedBytes: Int64?,
        expectedSHA256: String,
        label: String
    ) throws {
        let values = try? url.resourceValues(forKeys: [
            .fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey,
        ])
        guard values?.isRegularFile == true, values?.isSymbolicLink != true,
            expectedBytes == nil || Int64(values?.fileSize ?? -1) == expectedBytes,
            try QwenQualificationHashing.sha256(contentsOf: url) == expectedSHA256
        else {
            throw ScriptureModelQualificationError.modelIdentityMismatch(label)
        }
    }

    private static var qwenArtifactSetSHA256: String {
        let identity = QwenQualificationModelVerifier.productionArtifacts.map {
            "\($0.relativePath)\u{0}\($0.expectedBytes)\u{0}\($0.sha256)"
        }.sorted().joined(separator: "\n")
        return QwenQualificationHashing.sha256(Data(identity.utf8))
    }

    private static let hyMTModelBytes: Int64 = 1_133_080_448
    private static let hyMTModelSHA256 =
        "dc5f44fcf1fa496ee7ad725982c0c8c553a4de00259b53af84c4b89fb0c06699"
    private static let hyMTModelRevision = "1cd5208700acedef4ef93019b6cfc148b8522d45"
    private static let hyMTRuntimeRevision = "b10549"
}

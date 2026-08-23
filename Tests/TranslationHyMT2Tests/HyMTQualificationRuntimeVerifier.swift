import Foundation
import TranslationQualificationSupport
@testable import TranslationHyMT2

enum HyMTQualificationRuntimeVerifier {
    static func verify(
        _ configuration: HyMTQualificationConfiguration
    ) throws -> HyMTQualificationRuntimeSnapshot {
        let model = try HyMT2ModelResolver.resolve(
            at: configuration.modelURL,
            expectedFilename: configuration.providerConfiguration.modelFilename
        )
        let modelDigest = try verifyFile(
            model,
            bytes: 1_133_080_448,
            hash: HyMTQualificationConfiguration.modelSHA256,
            label: "Hy-MT2 model"
        )
        let runtime = try verifyRuntime(configuration.helperURL)
        return HyMTQualificationRuntimeSnapshot(
            model: modelDigest,
            helper: runtime.helper,
            runtimeBundle: runtime.bundle
        )
    }

    private static func verifyRuntime(_ helper: URL) throws -> RuntimeIdentity {
        let directory = helper.deletingLastPathComponent()
        guard helper.lastPathComponent == "llama-server" else {
            throw TranslationQualificationError.invalidManifest("unexpected helper filename")
        }
        let names = try Set(
            FileManager.default.contentsOfDirectory(atPath: directory.path)
        )
        guard names == Set(runtimeHashes.keys) else {
            throw TranslationQualificationError.invalidManifest("runtime file set mismatch")
        }
        var inputs: [HyMTQualificationFileInput] = []
        var helperDigest: TranslationQualificationArtifactDigest?
        for (name, expected) in runtimeHashes {
            let url = directory.appendingPathComponent(name)
            let bytes = name == "llama-server" ? 33_472 : nil
            let digest = try verifyFile(
                url,
                bytes: bytes,
                hash: expected,
                label: "runtime \(name)"
            )
            inputs.append(HyMTQualificationFileInput(relativePath: name, url: url))
            if name == "llama-server" { helperDigest = digest }
        }
        try verifyArchiveMarker(in: directory)
        guard let helperDigest else {
            throw TranslationQualificationError.invalidManifest("runtime helper is absent")
        }
        return RuntimeIdentity(
            helper: helperDigest,
            bundle: try HyMTQualificationFileHasher.bundle(inputs)
        )
    }

    private static func verifyArchiveMarker(in directory: URL) throws {
        let marker = directory.appendingPathComponent(".complete-b10549")
        let markerText = try String(contentsOf: marker, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard markerText == "71e4b31afb020d6b71894eb8d1f2c0693038aec3f41f672f9fafb5055c8f2226" else {
            throw TranslationQualificationError.invalidManifest("runtime archive marker mismatch")
        }
    }

    private static func verifyFile(
        _ url: URL,
        bytes: Int?,
        hash expected: String,
        label: String
    ) throws -> TranslationQualificationArtifactDigest {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw TranslationQualificationError.missingFile(label)
        }
        if let bytes {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard values.fileSize == bytes else {
                throw TranslationQualificationError.invalidManifest("\(label) byte count mismatch")
            }
        }
        let digest = try HyMTQualificationFileHasher.artifact(url)
        guard digest.sha256 == expected else {
            throw TranslationQualificationError.hashMismatch(
                label: label,
                expected: expected,
                actual: digest.sha256
            )
        }
        return digest
    }

    private static let runtimeHashes = [
        "llama-server": HyMTQualificationConfiguration.helperSHA256,
        "libggml-base.0.dylib": "dd47b2f937a041aab3013c86350dea27bbc5d03f2ad154f0a3f4f9d7dfac4827",
        "libggml-blas.0.dylib": "fab45ce5b26a5b3d61b8b66507a3b0c5957b795ae7540c105f316c56ddcfabb6",
        "libggml-cpu.0.dylib": "8cb0168cc3103ae992ef52bbb50d4a942cfb058bdaf43041aae198cd58c038f2",
        "libggml-metal.0.dylib": "052911e175fd752079d54aa6014520da02c6f37cf397eaebba7849a08c3f4790",
        "libggml-rpc.0.dylib": "a0338158f8be419186a11c0173116e3ee70ba9c55cd3165ecea93bce9146be90",
        "libggml.0.dylib": "ba2c2e16d64f978cb1647b748dd38e22810209dcf893d6d58339a8585b5bc97e",
        "libllama-common.0.dylib": "7d22c81bbb340bb13ce290076cba161ee69e8d2bdb7f6060edc175d93212e533",
        "libllama-server-impl.dylib": "34c609fdab9ea7872167e1ffa31b6beaaed4fb88178a641be9d1ad5072b4a0e9",
        "libllama.0.dylib": "c09fdc038bab8f879cecddf683593e4d02065e8c4d24c02b03ea6fe9af278a70",
        "libmtmd.0.dylib": "77000dff18db4d353665520e7de4585935dccec39f94ea466b5fdb596cc41e5f",
        "LICENSE": "94f29bbed6a22c35b992c5c6ebf0e7c92f13b836b90f36f461c9cf2f0f1d010d",
        ".complete-b10549": "45cc055f91ea229eedaf8dbc49d878d5fd716ac835e082495e53f6a0811010a3",
    ]
}

struct HyMTQualificationRuntimeSnapshot: Equatable {
    let model: TranslationQualificationArtifactDigest
    let helper: TranslationQualificationArtifactDigest
    let runtimeBundle: TranslationQualificationBundleDigest
}

private struct RuntimeIdentity {
    let helper: TranslationQualificationArtifactDigest
    let bundle: TranslationQualificationBundleDigest
}

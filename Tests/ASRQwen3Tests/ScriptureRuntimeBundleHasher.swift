import Foundation

enum ScriptureRuntimeBundleHasher {
    static func hash(_ inputs: [ScriptureVerifiedRuntimeFile]) throws -> String {
        let sorted = inputs.sorted {
            Array($0.name.utf8).lexicographicallyPrecedes(Array($1.name.utf8))
        }
        guard !sorted.isEmpty, Set(sorted.map(\.name)).count == sorted.count else {
            throw ScriptureModelQualificationError.modelIdentityMismatch(
                "llama-runtime-bundle"
            )
        }
        var framed = Data("QLR-FRAMED-FILE-BUNDLE-V1\0".utf8)
        for input in sorted {
            append(Data(input.name.utf8), to: &framed)
            append(UInt64(input.byteCount), to: &framed)
            append(Data(input.sha256.utf8), to: &framed)
        }
        return QwenQualificationHashing.sha256(framed)
    }

    private static func append(_ data: Data, to output: inout Data) {
        append(UInt64(data.count), to: &output)
        output.append(data)
    }

    private static func append(_ value: UInt64, to output: inout Data) {
        var bigEndian = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndian) { output.append(contentsOf: $0) }
    }
}

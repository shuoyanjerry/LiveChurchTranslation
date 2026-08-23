import Foundation
import TranslationQualificationSupport

struct HyMTQualificationFileInput {
    let relativePath: String
    let url: URL
}

enum HyMTQualificationFileHasher {
    static func artifact(_ url: URL) throws -> TranslationQualificationArtifactDigest {
        let before = try regularFileSize(url)
        let hash = try TranslationQualificationSHA256.hash(fileAt: url)
        let after = try regularFileSize(url)
        guard before == after else { throw invalid("qualification file changed while hashing") }
        return TranslationQualificationArtifactDigest(byteCount: before, sha256: hash)
    }

    static func bundle(
        _ inputs: [HyMTQualificationFileInput]
    ) throws -> TranslationQualificationBundleDigest {
        let sorted = inputs.sorted {
            Array($0.relativePath.utf8).lexicographicallyPrecedes(Array($1.relativePath.utf8))
        }
        guard !sorted.isEmpty, Set(sorted.map(\.relativePath)).count == sorted.count else {
            throw invalid("qualification bundle entries are empty or duplicated")
        }
        var framed = Data("QLR-FRAMED-FILE-BUNDLE-V1\0".utf8)
        var byteCount: Int64 = 0
        for input in sorted {
            try validateRelativePath(input.relativePath)
            let digest = try artifact(input.url)
            byteCount += digest.byteCount
            append(Data(input.relativePath.utf8), to: &framed)
            append(UInt64(digest.byteCount), to: &framed)
            append(Data(digest.sha256.utf8), to: &framed)
        }
        return TranslationQualificationBundleDigest(
            format: TranslationExecutionProvenance.bundleFormat,
            entryCount: sorted.count,
            byteCount: byteCount,
            sha256: TranslationQualificationSHA256.hash(data: framed)
        )
    }

    private static func regularFileSize(_ url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [
            .fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey,
        ])
        guard values.isRegularFile == true, values.isSymbolicLink != true,
            let size = values.fileSize, size > 0
        else { throw invalid("qualification bundle entry is not a nonempty regular file") }
        return Int64(size)
    }

    private static func validateRelativePath(_ value: String) throws {
        let components = value.split(separator: "/", omittingEmptySubsequences: false)
        guard !value.hasPrefix("/"), !components.isEmpty,
            components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
        else { throw invalid("qualification bundle path is unsafe") }
    }

    private static func append(_ data: Data, to output: inout Data) {
        append(UInt64(data.count), to: &output)
        output.append(data)
    }

    private static func append(_ value: UInt64, to output: inout Data) {
        var bigEndian = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndian) { output.append(contentsOf: $0) }
    }

    private static func invalid(_ message: String) -> TranslationQualificationError {
        .invalidReport(message)
    }
}

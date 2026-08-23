import CryptoKit
import Foundation

enum V3SelectedVADHashing {
    static func fingerprint(_ url: URL) throws -> V3SelectedVADFingerprint {
        guard try isRegularNonSymbolicFile(url) else { throw V3SelectedVADError.unsafeInput }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        var count: Int64 = 0
        while let data = try autoreleasepool(invoking: {
            try handle.read(upToCount: 4 * 1_024 * 1_024)
        }), !data.isEmpty {
            hasher.update(data: data)
            count += Int64(data.count)
        }
        return V3SelectedVADFingerprint(sha256: hex(hasher.finalize()), byteCount: count)
    }

    static func digest(_ data: Data) -> String {
        hex(SHA256.hash(data: data))
    }

    static func canonicalDigest<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return digest(try encoder.encode(value))
    }

    static func sourceBundle(
        roots: [(String, Set<String>)],
        workspaceRoot: URL,
        fileNamePrefix: String? = nil
    ) throws -> V3SelectedVADSourceBundle {
        let files = try roots.flatMap { relative, extensions in
            try sourceFiles(
                in: workspaceRoot.appendingPathComponent(relative, isDirectory: true),
                extensions: extensions
            )
        }.filter { fileNamePrefix == nil || $0.lastPathComponent.hasPrefix(fileNamePrefix ?? "") }
            .sorted { $0.path < $1.path }
        guard !files.isEmpty else { throw V3SelectedVADError.unsafeInput }
        var hasher = SHA256()
        for file in files {
            let relative = String(file.path.dropFirst(workspaceRoot.path.count + 1))
            update(&hasher, data: Data(relative.utf8))
            update(&hasher, data: try Data(contentsOf: file, options: [.uncached]))
        }
        return V3SelectedVADSourceBundle(sha256: hex(hasher.finalize()), fileCount: files.count)
    }

    static func isRegularNonSymbolicFile(_ url: URL) throws -> Bool {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    static func update(_ hasher: inout SHA256, data: Data) {
        var count = UInt64(data.count).littleEndian
        withUnsafeBytes(of: &count) { hasher.update(bufferPointer: $0) }
        hasher.update(data: data)
    }

    static func hex<Digest: Sequence>(_ digest: Digest) -> String
    where Digest.Element == UInt8 {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func sourceFiles(
        in directory: URL,
        extensions: Set<String>
    ) throws -> [URL] {
        guard
            let enumerator = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]
            )
        else { throw V3SelectedVADError.unsafeInput }
        return try enumerator.compactMap { value in
            guard let url = value as? URL, extensions.contains(url.pathExtension) else {
                return nil
            }
            guard try isRegularNonSymbolicFile(url) else { throw V3SelectedVADError.unsafeInput }
            return url
        }
    }
}

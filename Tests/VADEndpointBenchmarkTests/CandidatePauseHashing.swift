import CryptoKit
import Foundation

enum CandidatePauseHashing {
    static func selectedConfigurationDigest() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return digest(try encoder.encode(VADBenchmarkStrategy.webrtcStable.metadata))
    }

    static func productionSourceFingerprint(
        workspaceRoot: URL
    ) throws -> CandidatePauseSourceFingerprint {
        let swiftRoots = ["AudioProcessingAPI", "VADAPI", "VADCore", "VADWebRTC"].map {
            workspaceRoot.appendingPathComponent("Sources/\($0)", isDirectory: true)
        }
        let webRTCRoots = [
            "Sources/WebRTCVADC/Vendor/libfvad/src",
            "Sources/WebRTCVADC/Vendor/libfvad/include",
        ].map { workspaceRoot.appendingPathComponent($0, isDirectory: true) }
        let files = try
            (swiftRoots.flatMap(swiftFiles)
            + webRTCRoots.flatMap { try sourceFiles(in: $0, extensions: ["c", "h"]) }).sorted {
                $0.path < $1.path
            }
        return try fingerprint(files, workspaceRoot: workspaceRoot)
    }

    static func companionSourceFingerprint(
        workspaceRoot: URL
    ) throws -> CandidatePauseSourceFingerprint {
        let directory = workspaceRoot.appendingPathComponent(
            "Tests/VADEndpointBenchmarkTests",
            isDirectory: true
        )
        let package = workspaceRoot.appendingPathComponent("Package.swift")
        let files = try (swiftFiles(in: directory) + [validatedFile(package)])
            .sorted { $0.path < $1.path }
        return try fingerprint(files, workspaceRoot: workspaceRoot)
    }

    static func boundSourceFingerprints(
        workspaceRoot: URL
    ) throws -> CandidatePauseBoundSources {
        try CandidatePauseBoundSources(
            production: productionSourceFingerprint(workspaceRoot: workspaceRoot),
            companion: companionSourceFingerprint(workspaceRoot: workspaceRoot)
        )
    }

    static func digest(_ data: Data) -> String {
        hex(SHA256.hash(data: data))
    }

    private static func fingerprint(
        _ files: [URL],
        workspaceRoot: URL
    ) throws -> CandidatePauseSourceFingerprint {
        var hasher = SHA256()
        for file in files {
            let relative = String(file.path.dropFirst(workspaceRoot.path.count + 1))
            let data = try Data(contentsOf: file, options: [.mappedIfSafe, .uncached])
            update(&hasher, with: Data(relative.utf8))
            update(&hasher, with: data)
        }
        return CandidatePauseSourceFingerprint(
            sha256: hex(hasher.finalize()),
            fileCount: files.count
        )
    }

    private static func swiftFiles(in directory: URL) throws -> [URL] {
        try sourceFiles(in: directory, extensions: ["swift"])
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
        else { throw CandidatePauseBenchmarkError.invalidTrace("source enumeration failed") }
        return try enumerator.compactMap { value in
            guard let url = value as? URL, extensions.contains(url.pathExtension) else {
                return nil
            }
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw CandidatePauseBenchmarkError.invalidTrace("unsafe implementation source")
            }
            return url
        }
    }

    private static func validatedFile(_ url: URL) throws -> URL {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw CandidatePauseBenchmarkError.invalidTrace("unsafe companion source")
        }
        return url
    }

    private static func update(_ hasher: inout SHA256, with data: Data) {
        var length = UInt64(data.count).littleEndian
        withUnsafeBytes(of: &length) { hasher.update(bufferPointer: $0) }
        hasher.update(data: data)
    }

    private static func hex<Digest: Sequence>(_ digest: Digest) -> String
    where Digest.Element == UInt8 {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension CandidatePauseHashing {
    static func audioProcessingSourceFingerprint(
        workspaceRoot: URL
    ) throws -> CandidatePauseSourceFingerprint {
        let root = workspaceRoot.appendingPathComponent(
            "Sources/AudioProcessingAPI",
            isDirectory: true
        )
        return try fingerprint(try swiftFiles(in: root), workspaceRoot: workspaceRoot)
    }

    static func webRTCVendoredSourceFingerprint(
        workspaceRoot: URL
    ) throws -> CandidatePauseSourceFingerprint {
        let roots = [
            "Sources/WebRTCVADC/Vendor/libfvad/src",
            "Sources/WebRTCVADC/Vendor/libfvad/include",
        ].map { workspaceRoot.appendingPathComponent($0, isDirectory: true) }
        let files = try roots.flatMap {
            try sourceFiles(in: $0, extensions: ["c", "h"])
        }.sorted { $0.path < $1.path }
        return try fingerprint(files, workspaceRoot: workspaceRoot)
    }
}

struct CandidatePauseSourceFingerprint: Equatable {
    let sha256: String
    let fileCount: Int
}

struct CandidatePauseBoundSources: Equatable {
    let production: CandidatePauseSourceFingerprint
    let companion: CandidatePauseSourceFingerprint
}

import AVFoundation
import CryptoKit
import Foundation

struct VADCorpusEntry {
    let id: String
    let fileName: String
    let url: URL
}

struct VADAudioFingerprint: Equatable {
    let sha256: String
    let byteCount: Int64
}

enum VADBenchmarkCorpus {
    static func entries(in directory: URL) throws -> [VADCorpusEntry] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey]
        ).filter { $0.pathExtension.lowercased() == "wav" }.sorted {
            $0.lastPathComponent < $1.lastPathComponent
        }
        guard !urls.isEmpty else { throw VADBenchmarkError.noWAVFiles(directory.path) }
        return urls.enumerated().map { index, url in
            return VADCorpusEntry(
                id: String(format: "sermon-%02d", index + 1),
                fileName: url.lastPathComponent,
                url: url
            )
        }
    }

    static func samples(from buffer: AVAudioPCMBuffer) throws -> [Float] {
        guard let channels = buffer.floatChannelData else {
            throw VADBenchmarkError.unsupportedPCMFormat
        }
        return Array(UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength)))
    }

    static func fingerprint(_ url: URL) throws -> VADAudioFingerprint {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        var byteCount: Int64 = 0
        while let data = try autoreleasepool(invoking: {
            try handle.read(upToCount: 4 * 1_024 * 1_024)
        }), !data.isEmpty {
            hasher.update(data: data)
            byteCount += Int64(data.count)
        }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return VADAudioFingerprint(sha256: digest, byteCount: byteCount)
    }
}

enum VADBenchmarkError: Error {
    case noWAVFiles(String)
    case unsupportedPCMFormat
    case invalidAudioFormat(String)
    case audioIdentityChanged(String)
    case incompleteAudioRead(String)
    case unknownStrategy(String)
}

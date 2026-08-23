import CryptoKit
import Foundation

public enum TranslationQualificationSHA256 {
    public static func hash(data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func hash(fileAt url: URL) throws -> String {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw TranslationQualificationError.missingFile("qualification input")
        }
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw TranslationQualificationError.missingFile("qualification input")
        }
        defer { try? handle.close() }
        var hasher = SHA256()
        do {
            while true {
                let data = try handle.read(upToCount: 1_048_576) ?? Data()
                guard !data.isEmpty else { break }
                hasher.update(data: data)
            }
        } catch {
            throw TranslationQualificationError.invalidManifest("qualification input is unreadable")
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

import CryptoKit
import Foundation

public enum ScriptureQualificationSHA256 {
    public static func hash(data: Data) -> String {
        hexadecimal(SHA256.hash(data: data))
    }

    public static func hash(fileAt url: URL) throws -> String {
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw ScriptureQualificationError.invalidFile("unreadable file")
        }
        defer { try? handle.close() }
        var hasher = SHA256()
        do {
            while true {
                let chunk = try handle.read(upToCount: 1_048_576) ?? Data()
                guard !chunk.isEmpty else { break }
                hasher.update(data: chunk)
            }
        } catch {
            throw ScriptureQualificationError.invalidFile("unreadable file")
        }
        return hexadecimal(hasher.finalize())
    }

    private static func hexadecimal<D: Sequence>(_ digest: D) -> String
    where D.Element == UInt8 {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}

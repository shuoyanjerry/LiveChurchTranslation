import CryptoKit
import Foundation

enum QualificationSHA256 {
    static func data(_ data: Data) -> String {
        hexadecimal(SHA256.hash(data: data))
    }

    static func pcm(_ samples: [Float]) -> String {
        var hasher = SHA256()
        var offset = 0
        while offset < samples.count {
            let end = min(samples.count, offset + 4_096)
            var words = samples[offset..<end].map { $0.bitPattern.littleEndian }
            let bytes = words.withUnsafeMutableBytes { Data($0) }
            hasher.update(data: bytes)
            offset = end
        }
        return hexadecimal(hasher.finalize())
    }

    private static func hexadecimal<D: Sequence>(_ digest: D) -> String
    where D.Element == UInt8 {
        digest.map { String(format: "%02x", $0) }.joined()
    }
}

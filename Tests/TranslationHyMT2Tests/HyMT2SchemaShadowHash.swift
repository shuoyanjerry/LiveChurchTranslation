import CryptoKit
import Foundation

enum HyMT2SchemaShadowHash {
    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

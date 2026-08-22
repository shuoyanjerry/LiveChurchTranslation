import CryptoKit
import Foundation

enum CredentialHasher {
    static func hash(_ credential: String) -> Data {
        Data(SHA256.hash(data: Data(credential.utf8)))
    }

    static func matches(_ credential: String, hash expectedHash: Data) -> Bool {
        let candidate = hash(credential)
        guard candidate.count == expectedHash.count else { return false }
        return zip(candidate, expectedHash).reduce(UInt8(0)) { difference, pair in
            difference | (pair.0 ^ pair.1)
        } == 0
    }
}

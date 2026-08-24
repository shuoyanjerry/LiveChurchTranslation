import CryptoKit
import Foundation
import RemotePairingAPI

enum CredentialHasher {
    static func hash(_ credential: String) -> Data {
        Data(SHA256.hash(data: Data(credential.utf8)))
    }

    static func hash(
        _ credential: String,
        clientBinding: RemotePairingClientBinding
    ) -> Data {
        var scoped = Data(clientBinding.rawValue.utf8)
        scoped.append(0)
        scoped.append(contentsOf: credential.utf8)
        return Data(SHA256.hash(data: scoped))
    }

    static func matches(_ credential: String, hash expectedHash: Data) -> Bool {
        let candidate = hash(credential)
        return constantTimeMatches(candidate, expectedHash)
    }

    static func matches(
        _ credential: String,
        clientBinding: RemotePairingClientBinding,
        hash expectedHash: Data
    ) -> Bool {
        let candidate = hash(credential, clientBinding: clientBinding)
        return constantTimeMatches(candidate, expectedHash)
    }

    private static func constantTimeMatches(_ candidate: Data, _ expectedHash: Data) -> Bool {
        guard candidate.count == expectedHash.count else { return false }
        return zip(candidate, expectedHash).reduce(UInt8(0)) { difference, pair in
            difference | (pair.0 ^ pair.1)
        } == 0
    }
}

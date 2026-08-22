import Foundation
import Security

public protocol SecureTokenGenerating: Sendable {
    func token(byteCount: Int) throws -> String
}

public struct SystemSecureTokenGenerator: SecureTokenGenerating {
    public init() {}

    public func token(byteCount: Int) throws -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        guard status == errSecSuccess else {
            throw SecureTokenError.generationFailed(status)
        }
        return Data(bytes).base64URLEncodedString()
    }
}

public enum SecureTokenError: Error, Equatable, Sendable {
    case generationFailed(OSStatus)
}

extension Data {
    fileprivate func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

import CryptoKit
import Foundation
import SemanticEndpointAPI

enum SmartTurnModelIntegrity {
    static func validate(_ location: URL, identity: SmartTurnModelIdentity) throws {
        guard location.isFileURL else {
            throw SemanticEndpointError.modelFileUnavailable(location.absoluteString)
        }
        var isDirectory: ObjCBool = false
        let path = location.path
        guard
            FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
            !isDirectory.boolValue,
            FileManager.default.isReadableFile(atPath: path)
        else {
            throw SemanticEndpointError.modelFileUnavailable(path)
        }
        let data: Data
        do {
            data = try Data(contentsOf: location, options: .mappedIfSafe)
        } catch {
            throw SemanticEndpointError.modelFileUnavailable(path)
        }
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actual == identity.sha256 else {
            throw SemanticEndpointError.modelIntegrityMismatch(
                expected: identity.sha256,
                actual: actual
            )
        }
    }
}

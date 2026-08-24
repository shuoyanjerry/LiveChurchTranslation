import Foundation
import RemoteControlAPI
import RemotePairingAPI

extension RemoteHTTPRouter {
    func authorize(
        _ request: RemoteHTTPRequest,
        peer: RemotePeerAddress,
        mutation: Bool
    ) async throws -> RemoteControlAuthorization {
        guard let clientBinding = peer.pairingClientBinding else {
            throw RemoteTransportError.unauthorized
        }
        let credential = try RemoteCredentialExtractor.credential(from: request)
        do {
            let paired = try await pairing.authorize(
                bearerCredential: credential,
                clientBinding: clientBinding,
                requiresMutation: mutation,
                now: Date()
            )
            return RemoteControlAuthorization(
                peerID: paired.peerID,
                grantID: paired.grantID,
                role: paired.role
            )
        } catch PairingError.viewerIsReadOnly {
            throw PairingError.viewerIsReadOnly
        } catch {
            throw RemoteTransportError.unauthorized
        }
    }

    func requireJSON(_ request: RemoteHTTPRequest) throws {
        let type = request.singleHeader("content-type")?.lowercased() ?? ""
        guard
            type.split(separator: ";").first?.trimmingCharacters(in: .whitespaces)
                == "application/json"
        else {
            throw RemoteTransportError.malformedRequest
        }
    }
}

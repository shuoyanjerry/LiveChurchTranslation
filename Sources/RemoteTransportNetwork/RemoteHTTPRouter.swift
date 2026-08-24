import Foundation
import RemoteControlAPI
import RemotePairingAPI
import RemoteSharingAPI
import RemoteWebAssetsAPI

public struct RemoteHTTPRouter: Sendable {
    let security: RequestSecurityPolicy
    let sharing: any RemoteSharingControlling
    let pairing: any RemotePairingServing
    let projection: any RemoteProjectionProviding
    let commands: any RemoteSessionCommandHandling
    let assets: any RemoteWebAssetProviding
    let codec = RemoteJSONCodec()
    let secureCookies: Bool

    public init(
        security: RequestSecurityPolicy,
        sharing: any RemoteSharingControlling,
        pairing: any RemotePairingServing,
        projection: any RemoteProjectionProviding,
        commands: any RemoteSessionCommandHandling,
        assets: any RemoteWebAssetProviding,
        secureCookies: Bool = false
    ) {
        self.security = security
        self.sharing = sharing
        self.pairing = pairing
        self.projection = projection
        self.commands = commands
        self.assets = assets
        self.secureCookies = secureCookies
    }

    public func handle(_ request: RemoteHTTPRequest, peer: RemotePeerAddress) async -> RemoteHTTPResponse {
        do {
            return try await validatedResponse(request, peer: peer)
        } catch RemoteTransportError.unauthorized {
            return response(
                status: 401,
                reason: "Unauthorized",
                headers: ["Set-Cookie": RemoteGrantCookie.clearHeader]
            )
        } catch PairingError.viewerIsReadOnly {
            return response(status: 403, reason: "Forbidden")
        } catch PairingError.capacityReached {
            return response(status: 429, reason: "Too Many Requests")
        } catch {
            return response(status: 400, reason: "Bad Request")
        }
    }

}

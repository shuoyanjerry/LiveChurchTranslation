import Foundation
import RemoteControlAPI
import RemotePairingAPI

extension RemoteHTTPRouter {
    func validatedResponse(
        _ request: RemoteHTTPRequest,
        peer: RemotePeerAddress
    ) async throws -> RemoteHTTPResponse {
        try security.validateBase(request, peer: peer)
        guard await sharing.isEnabled() else { return response(status: 503, reason: "Unavailable") }
        if request.method == "GET", let asset = assets.asset(for: request.path) {
            return response(status: 200, reason: "OK", type: asset.contentType, body: asset.body)
        }
        switch (request.method, request.path) {
        case ("POST", "/api/pair"): return try await pair(request, peer: peer)
        case ("GET", "/api/snapshot"): return try await snapshot(request)
        case ("POST", "/api/control"): return try await control(request, peer: peer)
        default: return response(status: 404, reason: "Not Found")
        }
    }

    func pair(_ request: RemoteHTTPRequest, peer: RemotePeerAddress) async throws -> RemoteHTTPResponse {
        try security.validateMutation(request, peer: peer)
        try requireJSON(request)
        let redemption = try codec.decode(PairingRedemption.self, from: request.body)
        let now = Date()
        let grant = try await pairing.redeem(redemption, now: now)
        let body = try codec.encode(PairingResponse(role: grant.peer.role, expiresAt: grant.peer.expiresAt))
        let maxAge = Int(max(0, grant.peer.expiresAt.timeIntervalSince(now)))
        return response(
            status: 200,
            reason: "OK",
            type: "application/json; charset=utf-8",
            headers: [
                "Set-Cookie": RemoteGrantCookie.header(
                    credential: grant.bearerCredential,
                    maxAge: maxAge,
                    secure: secureCookies
                )
            ],
            body: body
        )
    }

    func snapshot(_ request: RemoteHTTPRequest) async throws -> RemoteHTTPResponse {
        let authorization = try await authorize(request, mutation: false)
        let body = try codec.encode(await projection.snapshot())
        return response(
            status: 200,
            reason: "OK",
            type: "application/json; charset=utf-8",
            headers: ["X-Remote-Role": authorization.role.rawValue],
            body: body
        )
    }

    func control(_ request: RemoteHTTPRequest, peer: RemotePeerAddress) async throws -> RemoteHTTPResponse {
        try security.validateMutation(request, peer: peer)
        try requireJSON(request)
        let authorization = try await authorize(request, mutation: true)
        let command = try codec.decode(RemoteControlRequest.self, from: request.body)
        let result = await commands.handle(command, authorization: authorization)
        let body = try codec.encode(result)
        return response(
            status: result.accepted ? 200 : 409,
            reason: result.accepted ? "OK" : "Conflict",
            type: "application/json; charset=utf-8",
            body: body
        )
    }
}

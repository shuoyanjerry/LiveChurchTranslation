import Foundation
import RemoteSharingAPI

struct PairingResponse: Codable, Sendable {
    let role: RemoteRole
    let expiresAt: Date
}

extension RemoteHTTPRouter {
    func response(
        status: Int,
        reason: String,
        type: String = "text/plain; charset=utf-8",
        headers: [String: String] = [:],
        body: Data = Data()
    ) -> RemoteHTTPResponse {
        var values = headers
        values["Content-Type"] = type
        values["Content-Length"] = String(body.count)
        return RemoteHTTPResponse(
            status: status,
            reason: reason,
            headers: SecureResponseHeaders.applying(to: values),
            body: body
        )
    }
}

import Foundation
import RemoteSharingAPI

extension NWRemoteConnectionHandler {
    func startOutgoingPump(_ session: RemoteSocketSession) {
        pumpTask?.cancel()
        pumpTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(75))
                guard !Task.isCancelled else { return }
                let envelopes = await session.outgoing(limit: 64)
                do {
                    for envelope in envelopes { try await self?.sendEnvelope(envelope) }
                } catch {
                    await self?.close()
                    return
                }
            }
        }
    }

    func sendEnvelope(_ envelope: RemoteProjectionEnvelope) async throws {
        let payload = try RemoteJSONCodec().encode(envelope)
        try await sendFrame(WebSocketFrame(opcode: .text, payload: payload))
    }

    func sendFrame(_ frame: WebSocketFrame) async throws {
        try await send(components.frameCodec.encodeServerFrame(frame))
    }

    func sendHTTPAndClose(_ response: RemoteHTTPResponse) async {
        var headers = response.headers
        headers["Connection"] = "close"
        let closing = RemoteHTTPResponse(
            status: response.status,
            reason: response.reason,
            headers: headers,
            body: response.body
        )
        do { try await send(HTTPResponseSerializer.serialize(closing)) } catch {}
        await close()
    }

    func sendError(status: Int, reason: String) async {
        let body = Data("Request rejected".utf8)
        let response = RemoteHTTPResponse(
            status: status,
            reason: reason,
            headers: SecureResponseHeaders.applying(to: [
                "Connection": "close",
                "Content-Length": String(body.count),
                "Content-Type": "text/plain; charset=utf-8",
            ]),
            body: body
        )
        do { try await send(HTTPResponseSerializer.serialize(response)) } catch {}
        await close()
    }

    func closeWebSocket(code: UInt16) async {
        let payload = Data([UInt8(code >> 8), UInt8(code & 0xFF)])
        try? await sendFrame(WebSocketFrame(opcode: .close, payload: payload))
        await close()
    }

    func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(
                content: data,
                completion: .contentProcessed { error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                })
        }
    }
}

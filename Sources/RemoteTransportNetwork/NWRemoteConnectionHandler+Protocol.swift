extension NWRemoteConnectionHandler {
    func processHTTP() async {
        let maximum = limits.maximumHeaderBytes + limits.maximumBodyBytes + 4
        guard buffer.count <= maximum else {
            await sendError(status: 413, reason: "Payload Too Large")
            return
        }
        do {
            let request = try components.parser.parse(buffer)
            buffer.removeAll(keepingCapacity: true)
            if request.path == "/ws" {
                try await upgrade(request)
            } else {
                let response = await components.httpRouter.handle(request, peer: peer)
                await sendHTTPAndClose(response)
            }
        } catch RemoteTransportError.incompleteRequest {
            receiveNext()
        } catch RemoteTransportError.headersTooLarge {
            await sendError(status: 431, reason: "Request Header Fields Too Large")
        } catch RemoteTransportError.bodyTooLarge {
            await sendError(status: 413, reason: "Payload Too Large")
        } catch {
            await sendError(status: 400, reason: "Bad Request")
        }
    }

    func upgrade(_ request: RemoteHTTPRequest) async throws {
        let opened = try await components.webSocketGateway.open(request: request, peer: peer)
        do {
            try await send(HTTPResponseSerializer.serialize(opened.handshakeResponse))
            guard !closed else {
                await opened.session.close()
                return
            }
            mode = .webSocket(opened.session)
            cancelHTTPHandshakeDeadline()
            try await opened.session.validateAuthorization()
            try await sendEnvelope(opened.initialEnvelope)
            startOutgoingPump(opened.session)
            receiveNext()
        } catch {
            await opened.session.close()
            await close()
        }
    }

    func processWebSocket(_ session: RemoteSocketSession) async {
        do {
            while !buffer.isEmpty {
                let parsed = try components.frameCodec.parseClientFrame(buffer)
                buffer.removeFirst(parsed.consumedBytes)
                if let response = try await session.receive(parsed.frame) {
                    try await sendFrame(response)
                    if response.opcode == .close {
                        await close()
                        return
                    }
                }
            }
            receiveNext()
        } catch RemoteTransportError.incompleteRequest {
            if buffer.count <= limits.maximumWebSocketFrameBytes + 14 {
                receiveNext()
            } else {
                await closeWebSocket(code: 1009)
            }
        } catch RemoteTransportError.unauthorized {
            await close()
        } catch RemoteTransportError.frameTooLarge {
            await closeWebSocket(code: 1009)
        } catch {
            await closeWebSocket(code: 1002)
        }
    }
}

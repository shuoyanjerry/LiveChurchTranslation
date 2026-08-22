import RemoteTransportAPI

extension NWRemoteTransportServer {
    func makeServerComponents(
        configuration: RemoteTransportConfiguration,
        port: UInt16
    ) -> RemoteServerComponents {
        let security = RequestSecurityPolicy(
            configuration: LocalHostAllowlist.make(
                advertisedHost: configuration.advertisedHostName,
                port: port
            ))
        let router = RemoteHTTPRouter(
            security: security,
            sharing: sharing,
            pairing: pairing,
            projection: projection,
            commands: commands,
            assets: assets
        )
        let gateway = RemoteWebSocketGateway(
            security: security,
            sharing: sharing,
            pairing: pairing,
            projection: projection
        )
        return RemoteServerComponents(
            parser: HTTPRequestParser(limits: limits),
            frameCodec: WebSocketFrameCodec(limits: limits),
            httpRouter: router,
            webSocketGateway: gateway
        )
    }
}

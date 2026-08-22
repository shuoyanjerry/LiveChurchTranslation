import Foundation
import RemoteControlAPI
import RemoteTransportNetwork
import Testing

@Suite("Remote HTTP router authorization")
struct RemoteHTTPRouterTests {
    @Test("A viewer mutation is denied before the session command handler")
    func viewerMutationDenied() async throws {
        let spy = CommandSpy()
        let router = RemoteHTTPRouter(
            security: .init(
                configuration: .init(
                    allowedHosts: ["reader.local:9000"],
                    allowedOrigins: ["http://reader.local:9000"]
                )),
            sharing: EnabledSharing(),
            pairing: ViewerPairing(),
            projection: ProjectionFake(),
            commands: spy,
            assets: EmptyAssets()
        )
        let command = RemoteControlRequest(command: .start, expectedRevision: 7)
        let request = RemoteHTTPRequest(
            method: "POST",
            target: "/api/control",
            path: "/api/control",
            query: nil,
            headers: [
                "host": ["reader.local:9000"],
                "origin": ["http://reader.local:9000"],
                "content-type": ["application/json"],
                "cookie": ["church_remote=\(String(repeating: "A", count: 43))"],
            ],
            body: try JSONEncoder().encode(command)
        )
        let response = await router.handle(request, peer: .init(host: "192.168.1.15"))
        #expect(response.status == 403)
        #expect(await spy.calls() == 0)
    }

    @Test("Control vocabulary contains only Start and Stop")
    func closedCommandVocabulary() {
        #expect(RemoteSessionCommand.allCasesForTesting == [.start, .stop])
    }
}

extension RemoteSessionCommand {
    fileprivate static var allCasesForTesting: [Self] { [.start, .stop] }
}

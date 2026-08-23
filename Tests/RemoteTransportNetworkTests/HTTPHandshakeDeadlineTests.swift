import Foundation
import RemoteTransportNetwork
import Testing

@Suite("HTTP handshake deadline")
struct HTTPHandshakeDeadlineTests {
    @Test("Silent and partial clients release the only connection slot", .timeLimit(.minutes(1)))
    func incompleteClientsReleaseCapacity() async throws {
        let fixture = try await DeadlineServerFixture.start(timeout: .milliseconds(250))
        do {
            let silentEvents = await fixture.server.events()
            let silent = try DeadlineTCPConnection(port: fixture.endpoint.port)
            try await silent.start()
            try await waitForConnectionRelease(silentEvents)
            await silent.cancel()
            #expect(try await fixture.assetStatus() == 200)

            let partialEvents = await fixture.server.events()
            let partial = try DeadlineTCPConnection(port: fixture.endpoint.port)
            try await partial.start()
            try await partial.send(Data("GET / HTTP/1.1\r\nHost: local".utf8))
            try await waitForConnectionRelease(partialEvents)
            await partial.cancel()
            #expect(try await fixture.assetStatus() == 200)
        } catch {
            await fixture.server.stop()
            throw error
        }
        await fixture.server.stop()
    }

    @Test("Handshake deadline is bounded for every injected configuration")
    func deadlineIsClamped() {
        let minimum = RemoteTransportLimits(httpHandshakeTimeout: .milliseconds(1))
        let maximum = RemoteTransportLimits(httpHandshakeTimeout: .seconds(90))

        #expect(minimum.httpHandshakeTimeout == .milliseconds(250))
        #expect(maximum.httpHandshakeTimeout == .seconds(30))
    }
}

import Foundation
import RemoteTransportAPI
@testable import RemoteTransportNetwork
import Testing

@Suite("Per-client connection admission")
struct ConnectionAdmissionTests {
    @Test("One LAN client cannot occupy every global connection slot", .timeLimit(.minutes(1)))
    func perClientLimit() async throws {
        let fixture = try await DeadlineServerFixture.start(
            timeout: .seconds(5),
            maximumConnections: 4,
            maximumConnectionsPerPeer: 2
        )
        let first = try DeadlineTCPConnection(port: fixture.endpoint.port)
        let second = try DeadlineTCPConnection(port: fixture.endpoint.port)
        let rejected = try DeadlineTCPConnection(port: fixture.endpoint.port)

        do {
            try await first.start()
            try await wait(for: 1, on: fixture.server)
            try await second.start()
            try await wait(for: 2, on: fixture.server)
            try? await rejected.start()
            try await Task.sleep(for: .milliseconds(150))
            #expect(await fixture.server.connections.count == 2)
            #expect(await fixture.server.connectionBindings.count == 2)
        } catch {
            await cancel(first, second, rejected)
            await fixture.server.stop()
            throw error
        }

        await cancel(first, second, rejected)
        await fixture.server.stop()
    }

    @Test("Per-client configuration never exceeds the global limit")
    func configurationClamp() {
        let configuration = RemoteTransportConfiguration(
            advertisedHostName: "reader.local",
            maximumConnections: 3,
            maximumConnectionsPerPeer: 9,
            bonjour: .init(name: "Reader", type: "_churchtranslate._tcp", textRecord: Data())
        )
        #expect(configuration.maximumConnections == 3)
        #expect(configuration.maximumConnectionsPerPeer == 3)
    }

    @Test("Bonjour reader pins successful sessions to IPv4", .timeLimit(.minutes(1)))
    func ipv4OnlyListener() async throws {
        let fixture = try await DeadlineServerFixture.start(timeout: .seconds(1))
        let ipv4 = try DeadlineTCPConnection(port: fixture.endpoint.port)
        let ipv6 = try DeadlineTCPConnection(host: "::1", port: fixture.endpoint.port)

        do {
            try await ipv4.start()
            #expect(!(await starts(ipv6, within: .milliseconds(500))))
        } catch {
            await cancel(ipv4, ipv6)
            await fixture.server.stop()
            throw error
        }

        await cancel(ipv4, ipv6)
        await fixture.server.stop()
    }

    private func wait(
        for expectedCount: Int,
        on server: NWRemoteTransportServer
    ) async throws {
        for _ in 0..<50 {
            if await server.connections.count == expectedCount { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        throw ConnectionAdmissionTestError.acceptanceTimedOut
    }

    private func cancel(_ connections: DeadlineTCPConnection...) async {
        for connection in connections { await connection.cancel() }
    }

    private func starts(
        _ connection: DeadlineTCPConnection,
        within timeout: Duration
    ) async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask { (try? await connection.start()) != nil }
            group.addTask {
                try? await Task.sleep(for: timeout)
                return false
            }
            let started = await group.next() ?? false
            if !started { await connection.cancel() }
            group.cancelAll()
            return started
        }
    }
}

private enum ConnectionAdmissionTestError: Error {
    case acceptanceTimedOut
}

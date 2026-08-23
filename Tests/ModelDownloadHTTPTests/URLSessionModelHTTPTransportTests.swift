import Foundation
@testable import ModelDownloadHTTP
import Synchronization
import Testing
@MainActor
@Suite(.serialized)
struct URLSessionModelHTTPTransportTests {
    @Test func rejectsDeclaredContentLengthAboveLimit() async throws {
        let fixture = try TransportFixture(
            response: .payload(
                statusCode: 200,
                headers: ["Content-Length": "9"],
                chunks: [Data("x".utf8)]
            )
        )
        defer { fixture.remove() }

        await fixture.expectFailure(
            .responseTooLarge(maximumBytes: 8),
            maximumBytes: 8
        )
    }

    @Test func cancelsUnknownLengthStreamAtFirstByteAboveLimit() async throws {
        let fixture = try TransportFixture(
            response: .payload(
                statusCode: 200,
                headers: [:],
                chunks: [Data(repeating: 1, count: 8), Data([2])]
            )
        )
        defer { fixture.remove() }

        await fixture.expectFailure(
            .responseTooLarge(maximumBytes: 8),
            maximumBytes: 8
        )
    }

    @Test(arguments: [
        "http://models.example.test/revision/model.bin",
        "https://models.example.test:444/revision/model.bin",
        "https://user@models.example.test/revision/model.bin",
        "https://models.example.test/revision/model.bin#fragment",
    ])
    func rejectsUnsafeRedirect(destination: String) throws {
        let redirectedURL = try #require(URL(string: destination))
        #expect(ModelHTTPRedirectPolicy.permits(redirectedURL) == false)
    }

    @Test func permitsHTTPSRedirectToModelCDN() throws {
        let redirectedURL = try #require(
            URL(string: "https://cdn-lfs.example.test/blobs/sha256?signature=value")
        )
        #expect(ModelHTTPRedirectPolicy.permits(redirectedURL))
    }

    @Test func movesExactResponseToDestination() async throws {
        let payload = Data("12345678".utf8)
        let fixture = try TransportFixture(
            response: .payload(
                statusCode: 200,
                headers: ["Content-Length": "8"],
                chunks: [Data(payload.prefix(3)), Data(payload.suffix(5))]
            )
        )
        defer { fixture.remove() }

        let result = try await fixture.transport.download(
            from: fixture.remoteURL,
            to: fixture.destinationURL,
            maximumBytes: 8
        ) { _, _ in }

        #expect(result == ModelHTTPTransferResult(statusCode: 200, contentLength: 8))
        #expect(try Data(contentsOf: fixture.destinationURL) == payload)
    }
}

@MainActor
private final class TransportFixture {
    let directory: TestDirectory
    let remoteURL: URL
    let destinationURL: URL
    let transport: URLSessionModelHTTPTransport

    init(response: StubURLProtocol.Response) throws {
        directory = try TestDirectory()
        remoteURL = try #require(
            URL(string: "https://models.example.test/revision/model.bin")
        )
        destinationURL = directory.url.appendingPathComponent("model.bin.part")
        StubURLProtocol.setResponse(response, for: remoteURL)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        transport = URLSessionModelHTTPTransport(
            session: URLSession(configuration: configuration)
        )
    }

    func expectFailure(
        _ expected: ModelHTTPTransportError,
        maximumBytes: Int64
    ) async {
        do {
            _ = try await transport.download(
                from: remoteURL,
                to: destinationURL,
                maximumBytes: maximumBytes
            ) { _, _ in }
            Issue.record("Expected transport failure \(expected).")
        } catch let error as ModelHTTPTransportError {
            #expect(error == expected)
        } catch {
            Issue.record("Unexpected transport error: \(error)")
        }
        #expect(FileManager.default.fileExists(atPath: destinationURL.path) == false)
    }

    func remove() {
        StubURLProtocol.removeResponse(for: remoteURL)
        directory.remove()
    }
}

private final class StubURLProtocol: URLProtocol {
    enum Response: Sendable {
        case payload(statusCode: Int, headers: [String: String], chunks: [Data])
    }

    private static let responses = Mutex<[URL: Response]>([:])

    static func setResponse(_ response: Response, for url: URL) {
        responses.withLock { $0[url] = response }
    }

    static func removeResponse(for url: URL) {
        responses.withLock { $0[url] = nil }
    }

    override static func canInit(with request: URLRequest) -> Bool {
        request.url != nil
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url,
            let response = Self.responses.withLock({ $0[url] })
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }

        switch response {
        case .payload(let statusCode, let headers, let chunks):
            guard
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: headers
                )
            else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            for chunk in chunks {
                client?.urlProtocol(self, didLoad: chunk)
            }
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}

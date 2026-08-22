import Foundation
import RemoteTransportNetwork
import Testing

@Suite("Bounded remote transport parsing")
struct HTTPRequestParserTests {
    @Test("Valid input parses and security-sensitive duplicates fail")
    func requestParsing() throws {
        let valid = Data("GET /reader.js HTTP/1.1\r\nHost: reader.local:9000\r\n\r\n".utf8)
        let request = try HTTPRequestParser().parse(valid)
        #expect(request.path == "/reader.js")
        let duplicate = Data(
            "GET / HTTP/1.1\r\nHost: reader.local\r\nHost: attacker.test\r\n\r\n".utf8
        )
        #expect(throws: RemoteTransportError.duplicateSecurityHeader) {
            try HTTPRequestParser().parse(duplicate)
        }
    }

    @Test("Headers, bodies, and transfer encodings are bounded")
    func malformedLimits() {
        let parser = HTTPRequestParser(limits: .init(maximumHeaderBytes: 2_048, maximumBodyBytes: 1_024))
        let largeHeader = Data(
            ("GET / HTTP/1.1\r\nHost: local\r\nX-Fill: " + String(repeating: "a", count: 2_100)).utf8
        )
        #expect(throws: RemoteTransportError.headersTooLarge) { try parser.parse(largeHeader) }
        let largeBody = Data(
            "POST /api/control HTTP/1.1\r\nHost: local\r\nContent-Length: 1025\r\n\r\n".utf8
        )
        #expect(throws: RemoteTransportError.bodyTooLarge) { try parser.parse(largeBody) }
        let chunked = Data(
            "POST /api/control HTTP/1.1\r\nHost: local\r\nTransfer-Encoding: chunked\r\n\r\n".utf8
        )
        #expect(throws: RemoteTransportError.unsupportedTransferEncoding) {
            try parser.parse(chunked)
        }
    }
}

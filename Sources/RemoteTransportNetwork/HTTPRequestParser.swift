import Foundation

public struct HTTPRequestParser: Sendable {
    private let limits: RemoteTransportLimits

    public init(limits: RemoteTransportLimits = RemoteTransportLimits()) {
        self.limits = limits
    }

    public func parse(_ data: Data) throws -> RemoteHTTPRequest {
        let block = try parseHeaderBlock(data)
        let requestLine = try parseRequestLine(block.lines.first)
        let headers = try parseHeaders(Array(block.lines.dropFirst()))
        let contentLength = try bodyLength(headers)
        guard contentLength <= limits.maximumBodyBytes else { throw RemoteTransportError.bodyTooLarge }
        let bodyStart = block.bodyStart
        guard data.count >= bodyStart + contentLength else { throw RemoteTransportError.incompleteRequest }
        guard data.count == bodyStart + contentLength else { throw RemoteTransportError.malformedRequest }
        let target = splitTarget(requestLine.target)
        return RemoteHTTPRequest(
            method: requestLine.method,
            target: requestLine.target,
            path: target.path,
            query: target.query,
            headers: headers,
            body: Data(data[bodyStart..<data.endIndex])
        )
    }

    private func parseHeaderBlock(_ data: Data) throws -> HTTPHeaderBlock {
        guard let boundary = data.range(of: Data("\r\n\r\n".utf8)) else {
            if data.count > limits.maximumHeaderBytes { throw RemoteTransportError.headersTooLarge }
            throw RemoteTransportError.incompleteRequest
        }
        let headerLength = boundary.lowerBound
        guard headerLength <= limits.maximumHeaderBytes else {
            throw RemoteTransportError.headersTooLarge
        }
        guard let headerText = String(data: data[..<boundary.lowerBound], encoding: .utf8) else {
            throw RemoteTransportError.malformedRequest
        }
        return HTTPHeaderBlock(
            lines: headerText.components(separatedBy: "\r\n"),
            bodyStart: boundary.upperBound
        )
    }

    private func parseRequestLine(_ line: String?) throws -> HTTPRequestLine {
        guard let line else { throw RemoteTransportError.malformedRequest }
        guard line.utf8.count <= limits.maximumRequestLineBytes else {
            throw RemoteTransportError.requestLineTooLarge
        }
        let requestParts = line.split(separator: " ", omittingEmptySubsequences: false)
        guard requestParts.count == 3,
            requestParts[2] == "HTTP/1.1"
        else {
            throw RemoteTransportError.malformedRequest
        }
        let method = String(requestParts[0])
        let target = String(requestParts[1])
        guard isToken(method), target.hasPrefix("/"), !target.contains("#") else {
            throw RemoteTransportError.malformedRequest
        }
        return HTTPRequestLine(method: method, target: target)
    }

    private func splitTarget(_ target: String) -> (path: String, query: String?) {
        let split = target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        return (String(split[0]), split.count == 2 ? String(split[1]) : nil)
    }

    private func parseHeaders(_ lines: [String]) throws -> [String: [String]] {
        guard lines.count <= limits.maximumHeaderCount else { throw RemoteTransportError.tooManyHeaders }
        var result: [String: [String]] = [:]
        for line in lines where !line.isEmpty {
            guard !line.first!.isWhitespace, let colon = line.firstIndex(of: ":") else {
                throw RemoteTransportError.malformedHeader
            }
            let name = String(line[..<colon]).lowercased()
            let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard isToken(name), !value.contains(where: { $0.isNewline || $0.asciiValue == 0 }) else {
                throw RemoteTransportError.malformedHeader
            }
            result[name, default: []].append(value)
        }
        for name in ["host", "content-length", "origin", "authorization"]
        where (result[name]?.count ?? 0) > 1 {
            throw RemoteTransportError.duplicateSecurityHeader
        }
        return result
    }

    private func bodyLength(_ headers: [String: [String]]) throws -> Int {
        if headers["transfer-encoding"] != nil { throw RemoteTransportError.unsupportedTransferEncoding }
        guard let raw = headers["content-length"]?.first else { return 0 }
        guard !raw.isEmpty, raw.utf8.allSatisfy({ (48...57).contains($0) }), let value = Int(raw) else {
            throw RemoteTransportError.malformedHeader
        }
        return value
    }

    private func isToken(_ value: some StringProtocol) -> Bool {
        !value.isEmpty
            && value.utf8.allSatisfy {
                $0 > 32 && $0 < 127 && !"()<>@,;:\\\"/[]?={} \t".utf8.contains($0)
            }
    }
}

private struct HTTPHeaderBlock {
    let lines: [String]
    let bodyStart: Int
}

private struct HTTPRequestLine {
    let method: String
    let target: String
}

import Foundation

public enum HTTPResponseSerializer {
    public static func serialize(_ response: RemoteHTTPResponse) throws -> Data {
        guard isSafe(response.reason), response.headers.allSatisfy({ isSafe($0.key) && isSafe($0.value) })
        else {
            throw RemoteTransportError.malformedHeader
        }
        var head = "HTTP/1.1 \(response.status) \(response.reason)\r\n"
        for (name, value) in response.headers.sorted(by: { $0.key < $1.key }) {
            head += "\(name): \(value)\r\n"
        }
        head += "\r\n"
        var bytes = Data(head.utf8)
        bytes.append(response.body)
        return bytes
    }

    private static func isSafe(_ value: String) -> Bool {
        !value.contains("\r") && !value.contains("\n") && !value.contains("\0")
    }
}

import Foundation

public struct RemoteHTTPRequest: Equatable, Sendable {
    public let method: String
    public let target: String
    public let path: String
    public let query: String?
    public let headers: [String: [String]]
    public let body: Data

    public init(
        method: String,
        target: String,
        path: String,
        query: String?,
        headers: [String: [String]],
        body: Data
    ) {
        self.method = method
        self.target = target
        self.path = path
        self.query = query
        self.headers = headers
        self.body = body
    }

    public func singleHeader(_ name: String) -> String? {
        let values = headers[name.lowercased()]
        return values?.count == 1 ? values?.first : nil
    }
}

public struct RemoteHTTPResponse: Equatable, Sendable {
    public let status: Int
    public let reason: String
    public let headers: [String: String]
    public let body: Data

    public init(status: Int, reason: String, headers: [String: String] = [:], body: Data = Data()) {
        self.status = status
        self.reason = reason
        self.headers = headers
        self.body = body
    }
}

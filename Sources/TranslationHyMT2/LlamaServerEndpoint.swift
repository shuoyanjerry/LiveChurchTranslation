import Foundation

struct LlamaServerEndpoint: Equatable, Sendable {
    let host: String
    let port: UInt16
    let apiKey: String

    init(host: String = "127.0.0.1", port: UInt16, apiKey: String) {
        self.host = host
        self.port = port
        self.apiKey = apiKey
    }

    static func randomLocal() -> LlamaServerEndpoint {
        LlamaServerEndpoint(
            port: UInt16.random(in: 49_152...65_535),
            apiKey: "lct-\(UUID().uuidString)-\(UUID().uuidString)"
        )
    }

    func url(path: String) throws -> URL {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = Int(port)
        components.path = path
        guard let url = components.url else {
            throw HyMT2Error.transportFailure("Invalid localhost endpoint.")
        }
        return url
    }
}

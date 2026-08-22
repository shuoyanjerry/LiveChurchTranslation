import Foundation

public enum RemoteCredentialExtractor {
    public static func credential(from request: RemoteHTTPRequest) throws -> String {
        let authorization = try authorizationCredential(request)
        let cookie = try cookieCredential(request)
        if let authorization, let cookie, authorization != cookie {
            throw RemoteTransportError.unauthorized
        }
        guard let credential = authorization ?? cookie, isCredentialShapeValid(credential) else {
            throw RemoteTransportError.unauthorized
        }
        return credential
    }

    private static func authorizationCredential(_ request: RemoteHTTPRequest) throws -> String? {
        guard let header = request.singleHeader("authorization") else { return nil }
        let parts = header.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count == 2, parts[0].lowercased() == "bearer" else {
            throw RemoteTransportError.unauthorized
        }
        return String(parts[1])
    }

    private static func cookieCredential(_ request: RemoteHTTPRequest) throws -> String? {
        let cookieHeaders = request.headers["cookie"] ?? []
        var matches: [String] = []
        for header in cookieHeaders {
            for part in header.split(separator: ";") {
                let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
                if pair.count == 2, pair[0].trimmingCharacters(in: .whitespaces) == "church_remote" {
                    matches.append(pair[1].trimmingCharacters(in: .whitespaces))
                }
            }
        }
        guard matches.count <= 1 else { throw RemoteTransportError.unauthorized }
        return matches.first
    }

    private static func isCredentialShapeValid(_ credential: String) -> Bool {
        credential.count == 43
            && credential.utf8.allSatisfy {
                (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0)
                    || $0 == 45 || $0 == 95
            }
    }
}

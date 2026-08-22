import Foundation

public enum SecureResponseHeaders {
    public static let contentSecurityPolicy = [
        "default-src 'self'",
        "script-src 'self'",
        "style-src 'self'",
        "connect-src 'self'",
        "img-src 'self' data:",
        "font-src 'none'",
        "object-src 'none'",
        "base-uri 'none'",
        "frame-ancestors 'none'",
        "form-action 'self'",
    ].joined(separator: "; ")

    public static func applying(to headers: [String: String] = [:]) -> [String: String] {
        var result = headers
        result["Cache-Control"] = "no-store, max-age=0"
        result["Content-Security-Policy"] = contentSecurityPolicy
        result["X-Content-Type-Options"] = "nosniff"
        result["Referrer-Policy"] = "no-referrer"
        result["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
        result["X-Frame-Options"] = "DENY"
        return result
    }
}

public enum RemoteGrantCookie {
    public static func header(credential: String, maxAge: Int, secure: Bool) -> String {
        var fields = [
            "church_remote=\(credential)",
            "Path=/",
            "Max-Age=\(max(0, maxAge))",
            "HttpOnly",
            "SameSite=Strict",
        ]
        if secure { fields.append("Secure") }
        return fields.joined(separator: "; ")
    }

    public static let clearHeader =
        "church_remote=; Path=/; Max-Age=0; HttpOnly; SameSite=Strict"
}

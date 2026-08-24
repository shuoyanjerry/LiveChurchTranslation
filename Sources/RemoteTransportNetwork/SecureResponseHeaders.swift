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
        result["Pragma"] = "no-cache"
        result["Expires"] = "0"
        result["Content-Security-Policy"] = contentSecurityPolicy
        result["X-Content-Type-Options"] = "nosniff"
        result["Referrer-Policy"] = "no-referrer"
        result["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
        result["X-Frame-Options"] = "DENY"
        result["Cross-Origin-Opener-Policy"] = "same-origin"
        result["Cross-Origin-Resource-Policy"] = "same-origin"
        result["X-Permitted-Cross-Domain-Policies"] = "none"
        return result
    }
}

public enum RemoteGrantCookie {
    public static func header(credential: String, maxAge: Int?, secure: Bool) -> String {
        var fields = [
            "church_remote=\(credential)",
            "Path=/",
            "HttpOnly",
            "SameSite=Strict",
        ]
        if let maxAge { fields.insert("Max-Age=\(max(0, maxAge))", at: 2) }
        if secure { fields.append("Secure") }
        return fields.joined(separator: "; ")
    }

    public static let clearHeader =
        "church_remote=; Path=/; Max-Age=0; HttpOnly; SameSite=Strict"
}

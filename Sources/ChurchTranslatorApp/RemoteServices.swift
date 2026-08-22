import Foundation
import RemoteProjectionSessionAdapter
import RemoteSharingFeature

struct RemoteServices {
    let sharingFeature: LocalNetworkSharingFeature
    let projectionAdapter: LiveSessionProjectionAdapter
}

enum LocalNetworkHostName {
    static var value: String {
        let raw = ProcessInfo.processInfo.hostName
            .lowercased()
            .replacingOccurrences(of: ".local", with: "")
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let filtered = raw.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        let label = String(filtered).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "\(String((label.isEmpty ? "quiet-liturgy-reader" : label).prefix(48))).local"
    }
}

import Foundation

struct SessionManifest: Codable, Sendable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date?
    let entryCount: Int
}

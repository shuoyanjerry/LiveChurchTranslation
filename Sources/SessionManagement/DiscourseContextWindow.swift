import DiscourseResolutionAPI

struct DiscourseContextWindow: Sendable {
    private(set) var entries: [VerifiedDiscourseTurn] = []

    mutating func append(_ entry: VerifiedDiscourseTurn) {
        entries.append(entry)
        if entries.count > 2 {
            entries.removeFirst(entries.count - 2)
        }
    }

    mutating func removeAll() {
        entries.removeAll(keepingCapacity: true)
    }
}

import TranslationAPI

struct TranslationContextWindow: Sendable {
    private(set) var entries: [TranslationContextEntry] = []

    mutating func append(_ entry: TranslationContextEntry) {
        entries.append(entry)
        if entries.count > 2 {
            entries.removeFirst(entries.count - 2)
        }
    }

    mutating func removeAll() {
        entries.removeAll(keepingCapacity: true)
    }
}

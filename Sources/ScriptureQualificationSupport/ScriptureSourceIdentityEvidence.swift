import ScriptureAPI

/// Non-expressive evidence safe for aggregate qualification reports.
public struct ScriptureSourceIdentityEvidence: Codable, Equatable, Sendable {
    public let itemID: String
    public let editionID: ScriptureEditionID
    public let audioSHA256: String
    public let referenceSHA256: String
    public let bookID: ScriptureBookID
    public let chapter: Int
    public let verseStart: Int
    public let verseEnd: Int
    public let partition: ScriptureQualificationPartition
    public let readingKind: ScriptureReadingKind

    public init(item: ScriptureQualificationItem) {
        itemID = item.id
        editionID = item.editionID
        audioSHA256 = item.audioSHA256
        referenceSHA256 = item.referenceSHA256
        bookID = item.bookID
        chapter = item.chapter
        verseStart = item.verseStart
        verseEnd = item.verseEnd
        partition = item.partition
        readingKind = item.readingKind
    }
}

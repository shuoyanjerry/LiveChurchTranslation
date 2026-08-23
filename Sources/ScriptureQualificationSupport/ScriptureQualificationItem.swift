import ScriptureAPI

public struct ScriptureQualificationItem: Codable, Sendable {
    public let id: String
    public let editionID: ScriptureEditionID
    public let textGrantID: String
    public let audioGrantID: String
    public let useKind: ScriptureUseKind
    public let partition: ScriptureQualificationPartition
    public let readingKind: ScriptureReadingKind
    public let languageTag: String
    public let audioPath: String
    public let audioSHA256: String
    public let referencePath: String
    public let referenceSHA256: String
    public let bookID: ScriptureBookID
    public let chapter: Int
    public let verseStart: Int
    public let verseEnd: Int
    public let speakerID: String
    public let recordingEnvironment: String

    public init(
        id: String,
        editionID: ScriptureEditionID,
        textGrantID: String,
        audioGrantID: String,
        useKind: ScriptureUseKind,
        partition: ScriptureQualificationPartition,
        readingKind: ScriptureReadingKind,
        languageTag: String,
        audioPath: String,
        audioSHA256: String,
        referencePath: String,
        referenceSHA256: String,
        bookID: ScriptureBookID,
        chapter: Int,
        verseStart: Int,
        verseEnd: Int,
        speakerID: String,
        recordingEnvironment: String
    ) {
        self.id = id
        self.editionID = editionID
        self.textGrantID = textGrantID
        self.audioGrantID = audioGrantID
        self.useKind = useKind
        self.partition = partition
        self.readingKind = readingKind
        self.languageTag = languageTag
        self.audioPath = audioPath
        self.audioSHA256 = audioSHA256
        self.referencePath = referencePath
        self.referenceSHA256 = referenceSHA256
        self.bookID = bookID
        self.chapter = chapter
        self.verseStart = verseStart
        self.verseEnd = verseEnd
        self.speakerID = speakerID
        self.recordingEnvironment = recordingEnvironment
    }
}

public enum ScriptureQualificationPartition: String, Codable, CaseIterable, Sendable {
    case development
    case sealedBlindQualification
}

public enum ScriptureReadingKind: String, Codable, CaseIterable, Sendable {
    case fullVerse
    case partialVerse
    case referenceOnly
}

public struct ScriptureQualificationTranslationPair: Codable, Sendable {
    public let id: String
    public let englishItemID: String
    public let simplifiedChineseItemID: String

    public init(id: String, englishItemID: String, simplifiedChineseItemID: String) {
        self.id = id
        self.englishItemID = englishItemID
        self.simplifiedChineseItemID = simplifiedChineseItemID
    }
}

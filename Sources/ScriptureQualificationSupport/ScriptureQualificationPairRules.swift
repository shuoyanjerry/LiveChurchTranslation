import ScriptureAPI

enum ScriptureQualificationPairRules {
    static func validate(
        _ pairs: [ScriptureQualificationTranslationPair],
        items: [String: ScriptureQualificationItem]
    ) throws -> Set<String> {
        guard !pairs.isEmpty else {
            throw ScriptureQualificationError.invalidManifest("translationPairs must not be empty")
        }
        var pairIDs = Set<String>()
        var itemIDs = Set<String>()
        var partitions = Set<ScriptureQualificationPartition>()
        var usedDeclarations = Set<String>()
        for pair in pairs {
            try ScriptureQualificationScalarRules.requireID(pair.id, label: "pair.id")
            guard pairIDs.insert(pair.id).inserted else {
                throw ScriptureQualificationError.invalidManifest("duplicate pair id")
            }
            let evidence = try validatePair(pair, items: items)
            guard
                itemIDs.insert(evidence.english.id).inserted,
                itemIDs.insert(evidence.chinese.id).inserted
            else {
                throw ScriptureQualificationError.invalidManifest("items may appear in only one pair")
            }
            partitions.insert(evidence.english.partition)
            usedDeclarations.formUnion(evidence.declarationIDs)
        }
        guard itemIDs == Set(items.keys) else {
            throw ScriptureQualificationError.invalidManifest("every item must belong to one pair")
        }
        guard partitions == Set(ScriptureQualificationPartition.allCases) else {
            throw ScriptureQualificationError.invalidManifest(
                "development and sealedBlindQualification partitions are both required"
            )
        }
        return usedDeclarations
    }

    private static func validatePair(
        _ pair: ScriptureQualificationTranslationPair,
        items: [String: ScriptureQualificationItem]
    ) throws -> PairEvidence {
        guard
            let english = items[pair.englishItemID],
            let chinese = items[pair.simplifiedChineseItemID]
        else {
            throw ScriptureQualificationError.invalidManifest("pair references a missing item")
        }
        guard
            english.editionID == .englishStandardVersion2025,
            chinese.editionID == .newPunctuationCUVShenSimplified1988
        else {
            throw ScriptureQualificationError.invalidManifest("pair edition direction mismatch")
        }
        guard samePassage(english, chinese) else {
            throw ScriptureQualificationError.invalidManifest("pair passage metadata mismatch")
        }
        return PairEvidence(
            english: english,
            chinese: chinese,
            declarationIDs: [
                english.textDeclarationID, english.audioDeclarationID,
                chinese.textDeclarationID, chinese.audioDeclarationID,
            ]
        )
    }

    private static func samePassage(
        _ lhs: ScriptureQualificationItem,
        _ rhs: ScriptureQualificationItem
    ) -> Bool {
        lhs.bookID == rhs.bookID
            && lhs.chapter == rhs.chapter
            && lhs.verseStart == rhs.verseStart
            && lhs.verseEnd == rhs.verseEnd
            && lhs.partition == rhs.partition
            && lhs.readingKind == rhs.readingKind
    }
}

private struct PairEvidence {
    let english: ScriptureQualificationItem
    let chinese: ScriptureQualificationItem
    let declarationIDs: Set<String>
}

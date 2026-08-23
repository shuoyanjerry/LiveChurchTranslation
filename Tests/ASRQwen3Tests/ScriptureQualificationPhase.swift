import ScriptureQualificationSupport

enum ScriptureQualificationPhase: String, Codable, Sendable {
    case development
    case sealed

    var partition: ScriptureQualificationPartition {
        switch self {
        case .development: .development
        case .sealed: .sealedBlindQualification
        }
    }

    func includes(_ partition: ScriptureQualificationPartition) -> Bool {
        partition == self.partition
    }

    func select(
        _ pairs: [ScriptureQualificationTranslationPair],
        partitionForItemID: (String) -> ScriptureQualificationPartition?
    ) throws -> [ScriptureQualificationTranslationPair] {
        let selected = try pairs.filter { pair in
            guard let english = partitionForItemID(pair.englishItemID),
                let chinese = partitionForItemID(pair.simplifiedChineseItemID),
                english == chinese
            else { throw ScriptureModelQualificationError.invalidCorpus }
            return includes(english)
        }
        guard !selected.isEmpty else {
            throw ScriptureModelQualificationError.invalidCorpus
        }
        return selected
    }
}

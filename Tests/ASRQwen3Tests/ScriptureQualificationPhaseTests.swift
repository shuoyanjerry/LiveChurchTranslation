import ScriptureQualificationSupport
import Testing

@Suite struct ScriptureQualificationPhaseTests {
    @Test("development and sealed select disjoint pair sets")
    func phaseSelectionIsDisjoint() throws {
        let development = pair("development")
        let sealed = pair("sealed")
        let partitions: [String: ScriptureQualificationPartition] = [
            "development-en": .development,
            "development-zh": .development,
            "sealed-en": .sealedBlindQualification,
            "sealed-zh": .sealedBlindQualification,
        ]

        let developmentSelection = try ScriptureQualificationPhase.development.select(
            [development, sealed],
            partitionForItemID: { partitions[$0] }
        )
        let sealedSelection = try ScriptureQualificationPhase.sealed.select(
            [development, sealed],
            partitionForItemID: { partitions[$0] }
        )

        #expect(developmentSelection.map(\.id) == ["development-pair"])
        #expect(sealedSelection.map(\.id) == ["sealed-pair"])
    }

    @Test("a cross-partition pair fails closed")
    func crossPartitionPairFailsClosed() {
        let pair = ScriptureQualificationTranslationPair(
            id: "mismatch-pair",
            englishItemID: "development-en",
            simplifiedChineseItemID: "sealed-zh"
        )
        #expect(throws: ScriptureModelQualificationError.invalidCorpus) {
            try ScriptureQualificationPhase.development.select(
                [pair],
                partitionForItemID: {
                    $0 == "development-en" ? .development : .sealedBlindQualification
                }
            )
        }
    }

    private func pair(_ prefix: String) -> ScriptureQualificationTranslationPair {
        ScriptureQualificationTranslationPair(
            id: "\(prefix)-pair",
            englishItemID: "\(prefix)-en",
            simplifiedChineseItemID: "\(prefix)-zh"
        )
    }
}

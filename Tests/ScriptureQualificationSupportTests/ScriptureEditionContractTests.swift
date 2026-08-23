import ScriptureAPI
import Testing

@Suite struct ScriptureEditionContractTests {
    @Test func productionPairPinsExactEditionsAndUsageContract() {
        let pair = ScriptureEditionPair.production

        #expect(pair.english.id == .englishStandardVersion2025)
        #expect(pair.english.editionLabel == "ESV Text Edition: 2025")
        #expect(pair.simplifiedChinese.id == .newPunctuationCUVShenSimplified1988)
        #expect(pair.simplifiedChinese.officialEditionReference == "CUNP1s")
        #expect(ScriptureUseKind.allCases == [.terminologyBaseline, .exactQuotation])
    }
}

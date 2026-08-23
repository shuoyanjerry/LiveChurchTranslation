import SettingsAPI
@testable import SessionManagement
import Testing

@Suite struct ScriptureBookTermCatalogTests {
    @Test func containsTheSixtySixBookProtestantCanon() {
        #expect(ScriptureBookTermCatalog.count == 66)
    }

    @Test func englishReferencesUseCuvNewPunctuationBookNames() throws {
        let terms = ScriptureBookTermCatalog.matchedTerms(
            in: "John 3:16 and First Corinthians 13",
            mode: .englishToSimplifiedChinese
        )

        #expect(terms.contains { $0.source == "John" && $0.target == "约翰福音" })
        #expect(
            terms.contains {
                $0.source == "1 Corinthians" && $0.target == "哥林多前书"
            }
        )
    }

    @Test func chineseReferencesUseEsvBookNames() {
        let terms = ScriptureBookTermCatalog.matchedTerms(
            in: "请读诗篇二十三篇和以弗所书二章八节。",
            mode: .mandarinToEnglish
        )

        #expect(terms.contains { $0.source == "诗篇" && $0.target == "Psalms" })
        #expect(terms.contains { $0.source == "以弗所书" && $0.target == "Ephesians" })
    }

    @Test func shortEnglishBookNamesRespectWordBoundaries() {
        let terms = ScriptureBookTermCatalog.matchedTerms(
            in: "The speaker was named Markham.",
            mode: .englishToSimplifiedChinese
        )

        #expect(!terms.contains { $0.source == "Mark" })
    }
}

import ScriptureAPI
import Testing
@testable import LiveReader

@Suite struct ScriptureSettingsPresentationTests {
    @Test func displaysTheProductionEditionPairAsTerminologyBaselines() {
        let editions = ScriptureEditionPair.production

        #expect(
            ScriptureSettingsPresentation.englishBaseline
                == "\(editions.english.abbreviation) · \(editions.english.editionLabel)"
        )
        #expect(
            ScriptureSettingsPresentation.simplifiedChineseBaseline
                == "\(editions.simplifiedChinese.abbreviation) · "
                + "\(editions.simplifiedChinese.fullName) · "
                + "\(editions.simplifiedChinese.publicationYear)"
        )
    }

    @Test func warnsThatGeneratedAidIsNotAnExactQuotation() {
        let notice = ScriptureSettingsPresentation.notice

        #expect(notice.contains(ScriptureEditionPair.terminologyBaselineNotice))
        #expect(notice.contains(ScriptureEditionPair.exactQuotationNotice))
        #expect(notice.contains("not an exact Bible quotation"))
        #expect(notice.contains("tester-supplied, edition-pinned source"))
        #expect(notice.contains("他/祂"))
    }
}

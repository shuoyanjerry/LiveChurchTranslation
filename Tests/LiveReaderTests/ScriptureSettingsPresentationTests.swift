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

        #expect(notice.contains("不是圣经逐字引文"))
        #expect(notice.contains("已锁定版本"))
        #expect(notice.contains("来源与哈希校验"))
        #expect(notice.contains("他／祂"))
    }
}

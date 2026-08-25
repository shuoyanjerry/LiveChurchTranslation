import Foundation
@testable import LiveReader
import SettingsAPI
import Testing

@Suite @MainActor struct SessionLibraryDisplayLanguageTests {
    @Test func recognitionLanguageUsesMechanicalTraditionalChineseCopy() {
        let mandarin = librarySummary(sourceLanguage: "zh-Hans", targetLanguage: "en")
        let english = librarySummary(sourceLanguage: "en", targetLanguage: "zh-Hans")
        let unknown = librarySummary(sourceLanguage: "fr", targetLanguage: "en")

        #expect(
            mandarin.recognitionLanguage(displayLanguage: .traditionalChinese)
                == "識別語言：普通話"
        )
        #expect(
            english.recognitionLanguage(displayLanguage: .traditionalChinese)
                == "識別語言：英語"
        )
        #expect(
            unknown.recognitionLanguage(displayLanguage: .traditionalChinese)
                == "識別語言：法語"
        )
    }

    @Test func searchMatchesSimplifiedAndTraditionalLanguageNames() async {
        let mandarin = librarySummary(sourceLanguage: "zh-Hans", targetLanguage: "en")
        let english = librarySummary(sourceLanguage: "en", targetLanguage: "zh-Hans")
        let viewModel = SessionLibraryViewModel(
            store: SessionLibraryStoreFake(summaries: [mandarin, english]),
            recoveryArtifacts: SessionLibraryRecoveryArtifactsFake()
        )
        await viewModel.load()

        viewModel.searchText = "英語"
        #expect(viewModel.filteredSessions.map(\.id) == [english.id])

        viewModel.searchText = "普通話"
        #expect(viewModel.filteredSessions.map(\.id) == [mandarin.id])
    }

    @Test func destructiveAndImportCopyAreMechanicallyConverted() {
        #expect(
            SessionLibraryPresentation.deletionMessage(displayLanguage: .traditionalChinese)
                == "聽抄稿和完整錄音將從此 Mac 刪除，且無法恢復。"
        )
        #expect(
            SessionLibraryPresentation.importLanguageLabel(
                for: .mandarinToEnglish,
                displayLanguage: .traditionalChinese
            ) == "普通話內容"
        )
        #expect(
            SessionLibraryPresentation.importHelp(displayLanguage: .traditionalChinese)
                == "選擇內容語言；支持常見音頻和含音軌視頻，只生成聽抄稿，不會翻譯。"
        )
    }
}

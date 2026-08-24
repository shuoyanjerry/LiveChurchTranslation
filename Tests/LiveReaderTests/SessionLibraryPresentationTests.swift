import Foundation
@testable import LiveReader
import Testing
import TranscriptAPI

@Suite @MainActor struct SessionLibraryPresentationTests {
    @Test func storedTranscriptDisplaysRecognitionOnly() {
        let source = "恩典拯救我们。"
        let translation = "Grace saves us."
        let entry = TranscriptEntry(
            sequence: 1,
            sourceText: source,
            targetText: translation,
            startedMilliseconds: 0,
            endedMilliseconds: 1_000,
            translationMilliseconds: 10
        )

        let presentation = LibraryTranscriptEntry(entry: entry)

        #expect(presentation.displayText == source)
        #expect(presentation.displayText != translation)
    }

    @Test func storedSessionPresentsOnlyItsRecognitionLanguage() {
        let mandarin = librarySummary(sourceLanguage: "zh-Hans", targetLanguage: "en")
        let english = librarySummary(sourceLanguage: "en", targetLanguage: "zh-Hans")
        let unknown = librarySummary(sourceLanguage: "fr", targetLanguage: "en")
        let unsupportedPair = librarySummary(sourceLanguage: "zh-Hans", targetLanguage: "fr")

        #expect(mandarin.recognitionLanguage == "识别语言：普通话")
        #expect(english.recognitionLanguage == "识别语言：英语")
        #expect(unknown.recognitionLanguage == "识别语言：法语")
        #expect(unsupportedPair.recognitionLanguage == "识别语言：普通话")
        #expect(mandarin.storedTranslationMode == .mandarinToEnglish)
        #expect(english.storedTranslationMode == .englishToSimplifiedChinese)
        #expect(unsupportedPair.storedTranslationMode == nil)
    }

    @Test func searchMatchesSourceLanguageButNotTargetLanguage() async {
        let mandarin = librarySummary(sourceLanguage: "zh-Hans", targetLanguage: "en")
        let english = librarySummary(sourceLanguage: "en", targetLanguage: "zh-Hans")
        let viewModel = SessionLibraryViewModel(
            store: SessionLibraryStoreFake(summaries: [mandarin, english]),
            recoveryArtifacts: SessionLibraryRecoveryArtifactsFake()
        )
        await viewModel.load()

        viewModel.searchText = "英语"
        #expect(viewModel.filteredSessions.map(\.id) == [english.id])

        viewModel.searchText = "普通话"
        #expect(viewModel.filteredSessions.map(\.id) == [mandarin.id])

        viewModel.searchText = "简体中文"
        #expect(viewModel.filteredSessions.isEmpty)
    }

    @Test func deletionCopyDoesNotClaimTranslationsAreStored() {
        #expect(SessionLibraryPresentation.deletionMessage == "听抄稿和完整录音将从此 Mac 删除，且无法恢复。")
        #expect(!SessionLibraryPresentation.deletionMessage.contains("翻译"))
    }
}

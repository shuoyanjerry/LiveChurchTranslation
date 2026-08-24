import AudioImportAPI
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
        #expect(mandarin.storedRecognitionMode == .mandarinToEnglish)
        #expect(english.storedRecognitionMode == .englishToSimplifiedChinese)
        #expect(unsupportedPair.storedRecognitionMode == .mandarinToEnglish)
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

    @Test func audioImportCopyPromisesSourceTranscriptionOnly() {
        #expect(
            SessionLibraryPresentation.importLanguageLabel(for: .mandarinToEnglish)
                == "普通话录音"
        )
        #expect(
            SessionLibraryPresentation.importLanguageLabel(for: .englishToSimplifiedChinese)
                == "英语录音"
        )
        #expect(SessionLibraryPresentation.importHelp == "选择录音语言，只生成听抄稿，不会翻译。")
        #expect(!SessionLibraryPresentation.importHelp.contains("方向"))
        #expect(
            AudioImportError.liveSessionRunning.errorDescription
                == "请先停止当前现场会话，再导入并听抄音频文件。"
        )
    }

    @Test func liveSessionMustStopBeforeImport() async {
        let unexpected = librarySummary()
        let store = SessionLibraryStoreFake()
        let viewModel = SessionLibraryViewModel(
            store: store,
            recoveryArtifacts: SessionLibraryRecoveryArtifactsFake()
        )
        let importer = SessionLibraryImporterFake { await store.add(unexpected) }

        await viewModel.importAudio(
            from: URL(fileURLWithPath: "/tmp/import.wav"),
            mode: .mandarinToEnglish,
            using: importer,
            liveSessionIsRunning: true
        )

        #expect(viewModel.sessions.isEmpty)
        #expect(viewModel.presentedError == "请先停止当前现场会话。")
        #expect(await store.recentCallCount() == 0)
    }
}

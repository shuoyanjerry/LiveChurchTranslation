import PersistenceAPI
@testable import LiveReader
import Testing

@Suite struct StoredSessionRecoveryPresentationTests {
    @Test func incompleteSegmentsReceivePlainLanguageRecoveryCopy() throws {
        let summary = librarySummary(
            integrity: .incomplete,
            pendingRecordCount: 2,
            rejectedSentenceCount: 1
        )
        let presentation = try #require(
            IncompleteTranscriptPresentation(summary: summary)
        )

        #expect(presentation.segmentCount == 3)
        #expect(presentation.title == "这份听抄稿可能少了一些内容")
        #expect(
            presentation.detail(canRetranscribe: true)
                == "有 3 段内容尚未完整呈现。完整录音仍保存在这台 Mac 上，可以重新生成一份听抄稿。"
        )
        let publicCopy = presentation.title + presentation.detail(canRetranscribe: true)
        for technicalTerm in ["ASR", "模型", "错误码", "拒绝", "队列"] {
            #expect(!publicCopy.contains(technicalTerm))
        }
    }

    @Test func unrelatedIncompleteIntegrityDoesNotOfferRetranscription() {
        let summary = librarySummary(integrity: .incomplete)

        #expect(IncompleteTranscriptPresentation(summary: summary) == nil)
        #expect(!summary.hasIncompleteSpeechSegments)
    }

    @Test func presentationRestoresRecognitionModeFromSourceLanguageOnly() {
        let mandarin = librarySummary()
        let english = librarySummary(
            sourceLanguage: "en",
            targetLanguage: "zh-Hans"
        )
        let unknown = librarySummary(
            sourceLanguage: "fr",
            targetLanguage: "en"
        )

        #expect(mandarin.storedRecognitionMode == .mandarinToEnglish)
        #expect(english.storedRecognitionMode == .englishToSimplifiedChinese)
        #expect(unknown.storedRecognitionMode == nil)
    }

    @Test func retranscriptionTitleAddsItsSuffixOnlyOnce() {
        let original = librarySummary(title: "主日信息")
        let retried = librarySummary(title: "主日信息（重新听抄）")

        #expect(original.retranscriptionTitle == "主日信息（重新听抄）")
        #expect(retried.retranscriptionTitle == "主日信息（重新听抄）")
    }
}

import PersistenceAPI

struct IncompleteTranscriptPresentation: Equatable {
    let segmentCount: Int

    init?(summary: StoredSessionSummary) {
        let count = summary.pendingRecordCount + summary.rejectedSentenceCount
        guard count > 0 else { return nil }
        segmentCount = count
    }

    var title: String { "这份听抄稿可能少了一些内容" }

    func detail(canRetranscribe: Bool) -> String {
        let prefix = "有 \(segmentCount) 段内容尚未完整呈现。"
        if canRetranscribe {
            return prefix + "完整录音仍保存在这台 Mac 上，可以重新生成一份听抄稿。"
        }
        return prefix + "已经完成的内容仍可正常查看。"
    }
}

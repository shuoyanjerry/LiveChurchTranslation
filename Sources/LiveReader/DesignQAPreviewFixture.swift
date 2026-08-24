#if DEBUG
    import Foundation
    import SessionManagementAPI
    import TranscriptAPI

    enum DesignQAPreviewFixture {
        static var phase: LiveSessionPhase {
            switch UserDefaults.standard.string(
                forKey: "LiveChurchTranslationDesignPreviewPhase"
            ) {
            case "preparing": .preparingModel
            case "listening": .listening
            case "recognizing": .recognizing
            case "translating": .translating
            case "stopping": .stopping
            case "failed": .failed(message: "Design QA")
            default: .idle
            }
        }

        static func captureStartedAt(for phase: LiveSessionPhase) -> Date? {
            guard phase.keepsPreviewCaptureActive else { return nil }
            let elapsed = UserDefaults.standard.double(
                forKey: "LiveChurchTranslationDesignPreviewRecordingSeconds"
            )
            return elapsed > 0 ? Date().addingTimeInterval(-elapsed) : nil
        }

        static func sessionID(for phase: LiveSessionPhase) -> UUID? {
            guard phase.keepsPreviewSessionActive else { return nil }
            return UUID(uuidString: "00000000-0000-0000-0000-000000000024")
        }

        static func statusMessage(for phase: LiveSessionPhase) -> String {
            switch phase {
            case .idle: "听抄稿已保存"
            case .preparingModel: "正在准备"
            case .listening: "正在聆听"
            case .recognizing: "正在识别"
            case .translating: "正在翻译"
            case .stopping: "正在完成"
            case .failed: "听抄未完整保存"
            case .requestingPermission: "正在等待麦克风权限"
            }
        }

        static var transcript: [TranscriptEntry] {
            passages.enumerated().map { index, passage in
                TranscriptEntry(
                    sequence: index + 1,
                    sourceText: passage.source,
                    targetText: passage.target,
                    startedMilliseconds: Int64(index * 42_000),
                    endedMilliseconds: Int64(index * 42_000 + 8_000),
                    translationMilliseconds: 680
                )
            }
        }

        private static let passages = [
            Passage(
                source: "弟兄姊妹，今天我们一同来看神救恩的恩典。",
                target: "Brothers and sisters, today we consider together the grace of God's salvation."
            ),
            Passage(
                source: "救恩本乎恩典，也因着信，并不是出于行为。",
                target: "Salvation is by grace through faith, and it does not come from works."
            ),
            Passage(
                source: "我们因信称义，也在圣灵里一步一步被成圣。",
                target: "We are justified by faith and are also sanctified step by step in the Holy Spirit."
            ),
            Passage(
                source: "基督在十字架上的赎罪，使我们得着重生的生命。",
                target: "Christ's atonement on the cross gives us the life of regeneration."
            ),
            Passage(
                source: "三位一体的神呼召教会活在真实的团契里。",
                target: "The triune God calls the church to live in genuine fellowship."
            ),
            Passage(
                source: "我们借着事奉、圣餐和洗礼，一同见证福音。",
                target: "Through ministry, the Lord's Supper, and baptism, "
                    + "we bear witness to the gospel together."
            ),
            Passage(
                source: "愿我们忠实地听主的话，也彼此扶持、同被建造。",
                target:
                    "May we listen faithfully to the Lord's word, support one another, and be built together."
            ),
        ]
    }

    private struct Passage {
        let source: String
        let target: String
    }

    extension LiveSessionPhase {
        fileprivate var keepsPreviewSessionActive: Bool {
            switch self {
            case .requestingPermission, .preparingModel, .listening, .recognizing,
                .translating, .stopping:
                true
            case .idle, .failed:
                false
            }
        }

        fileprivate var keepsPreviewCaptureActive: Bool {
            switch self {
            case .preparingModel, .listening, .recognizing, .translating:
                true
            case .idle, .requestingPermission, .stopping, .failed:
                false
            }
        }
    }
#endif

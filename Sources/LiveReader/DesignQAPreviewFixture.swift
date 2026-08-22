#if DEBUG
    import TranscriptAPI

    enum DesignQAPreviewFixture {
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
#endif

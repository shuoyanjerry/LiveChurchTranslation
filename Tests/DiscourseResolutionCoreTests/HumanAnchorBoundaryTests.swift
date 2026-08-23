import DiscourseResolutionAPI
import DiscourseResolutionCore
import Testing

@Suite struct HumanAnchorBoundaryTests {
    private let resolver = DiscourseResolver()

    @Test func eventAndProductCompoundsNeverBecomePeople() {
        let examples = [
            "母亲节活动结束，所以他开始分享。",
            "父亲节活动结束，所以她开始分享。",
            "女士衬衫售完了，所以他开始分享。",
            "男人装上架了，所以她开始分享。",
        ]

        for text in examples {
            let result = resolve(text)

            #expect(result.resolvedText == text)
            #expect(result.corrections.isEmpty)
            #expect(result.pronounGuidance.first?.resolution == .unresolved)
        }
    }

    @Test func embeddedHumanTermDoesNotCrossLexicalBoundary() {
        let result = resolve("岳母亲自到了，所以他开始分享。")

        #expect(result.resolvedText == result.originalText)
        #expect(result.corrections.isEmpty)
        #expect(result.pronounGuidance.first?.resolution == .unresolved)
    }

    @Test func clearAppellationsStillResolveCurrentTurnPronouns() {
        let examples = [
            ("母亲讲完了，所以他坐下。", "母亲讲完了，所以她坐下。"),
            ("父亲讲完了，所以她坐下。", "父亲讲完了，所以他坐下。"),
            ("女士讲完了，所以他坐下。", "女士讲完了，所以她坐下。"),
            ("男人讲完了，所以她坐下。", "男人讲完了，所以他坐下。"),
            ("那位老姐妹讲完了，所以他坐下。", "那位老姐妹讲完了，所以她坐下。"),
        ]

        for (source, expected) in examples {
            #expect(resolve(source).resolvedText == expected)
        }
    }

    @Test func laterPluralAnchorDoesNotBlockEarlierCandidateEvidence() {
        let result = resolve("姐妹讲完了，所以他分享。弟兄们随后到了。")

        #expect(result.resolvedText == "姐妹讲完了，所以她分享。弟兄们随后到了。")
        #expect(result.corrections.count == 1)
    }

    private func resolve(_ text: String) -> DiscourseResolutionResult {
        resolver.resolve(
            DiscourseResolutionRequest(
                currentSequence: 10,
                currentText: text,
                verifiedTurns: []
            )
        )
    }
}

import Testing
@testable import TranslationHyMT2

@Suite struct HyMT2ProductionNegationValidatorTests {
    @Test func corpusLexicalBuFormsDoNotTriggerSurfaceFalseRejects() {
        let cases = [
            (
                "每一次打开新闻，都让人感到世界越来越不可预测。",
                "Every time we open the news, the world feels increasingly unpredictable."
            ),
            (
                "不同地区虽各有取向，但都试图靠知识，而不是神，建立未来秩序。",
                "Different regions rely on knowledge rather than God to build a future order."
            ),
            (
                "我们会不会在不知不觉中逐渐远离神？",
                "Will we unknowingly drift away from God?"
            ),
            ("他陷入极度的不安和恐惧。", "He fell into extreme anxiety and fear."),
            ("这与他是祷告的勇士密不可分。", "This is closely tied to his life of prayer."),
            ("神的应许不论有多少，在基督里都是是的。", "All God's promises are yes in Christ."),
            ("教会人数不多。", "The church is small."),
            ("如果细胞不受限，就发展为癌细胞。", "If cells are unrestricted, they become cancerous."),
            ("不可一世的君王都过去了。", "The mighty kings of the past are gone."),
            ("骨头是不断生长的。", "Bones grow continuously."),
        ]

        for value in cases {
            #expect(!hasMissingNegation(source: value.0, target: value.1))
        }
    }

    @Test func catchesObservedSermonNegationInversionByCount() {
        let source =
            "没有经过祷告的行动常常带着冲动，没有等候的行动常常被欲望驱使。"
            + "扫罗王因为不愿意等候而贸然献祭。"
        let inverted =
            "Actions that lack prayer are impulsive, while actions driven by desire involve "
            + "waiting. Saul offered a sacrifice because he was unwilling to wait."
        let faithful =
            "Actions taken without prayer are impulsive, and actions taken without waiting are "
            + "often driven by desire. Saul offered a sacrifice because he was unwilling to wait."

        #expect(hasMissingNegation(source: source, target: inverted))
        #expect(!hasMissingNegation(source: source, target: faithful))
    }

    @Test func englishToChineseRequiresEveryIndependentOvertCue() {
        let source = "The church does not hide truth and does not ignore the poor."

        #expect(
            hasMissingNegation(
                source: source,
                target: "教会不隐藏真理，却忽略穷人。",
                sourceLanguage: "en",
                targetLanguage: "zh-Hans"
            )
        )
        #expect(
            !hasMissingNegation(
                source: source,
                target: "教会不隐藏真理，也不忽略穷人。",
                sourceLanguage: "en",
                targetLanguage: "zh-Hans"
            )
        )
    }

    private func hasMissingNegation(
        source: String,
        target: String,
        sourceLanguage: String = "zh-Hans",
        targetLanguage: String = "en"
    ) -> Bool {
        HyMT2FidelityValidator.issues(
            target: target,
            source: source,
            requiredTerms: [],
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        ).contains(.missingNegation)
    }
}

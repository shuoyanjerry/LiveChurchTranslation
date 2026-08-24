import Testing
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMT2SafetyFallbackBestEffortTests {
    @Test func qualityImperfectThirdCompletionIsStillShownForBackendReview() async throws {
        let source = "她没有忘记3个人。"
        let harness = try await makeTranslationHarness(
            responses: [
                .success(source),
                .success(source),
                .success("She forgot 3 people."),
            ]
        )
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(safetyFallbackRequest(source))

        #expect(result.targetText == "She forgot 3 people.")
        #expect(
            result.review?.issueCodes
                == ["quality.missing_negation", "quality.pronoun_alignment"]
        )
        #expect(await harness.transport.completionRequests().count == 3)
    }

    @Test func missingSourceNumberIsShownForReviewWithoutEchoingTheNumber() async throws {
        let source = "她在4111111111111111天后继续。"
        let harness = try await makeTranslationHarness(
            responses: [.success(source), .success(source), .success("She continued.")]
        )
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(safetyFallbackRequest(source))

        #expect(result.targetText == "She continued.")
        #expect(!result.targetText.contains("4111111111111111"))
        #expect(
            result.review?.issueCodes
                == ["quality.missing_number", "quality.pronoun_alignment"]
        )
    }

    @Test func backendReviewCodesRemainUniqueAndSorted() async throws {
        let source = "她忠信。"
        let harness = try await makeTranslationHarness(
            responses: [.success(source), .success(source), .success("神 is faithful.")]
        )
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(safetyFallbackRequest(source))

        #expect(result.targetText == "神 is faithful.")
        #expect(
            result.review?.issueCodes
                == ["quality.pronoun_alignment", "quality.unexpected_script"]
        )
    }
}

extension HyMT2SafetyFallbackBestEffortTests {
    @Test func severelyTruncatedChineseToEnglishOutputIsFlagged() {
        let source =
            "教会在每一次聚会中都领受主丰富的恩典，也借着彼此扶持、恒切祷告、"
            + "忠心服事和传扬福音，一同见证基督已经完成的救赎工作。"
        let issues = fidelityIssues(
            target: "The church receives grace and serves Christ.",
            source: source
        )
        #expect(issues.contains(.implausibleLength))
    }

    @Test func severelyTruncatedEnglishToChineseOutputIsFlagged() {
        let source =
            "The church gathers to receive the Lord's abundant grace, to support one another, "
            + "to pray steadfastly, to serve faithfully, and to bear witness together to the "
            + "redemption that Jesus Christ has fully accomplished for His people."
        let issues = fidelityIssues(
            target: "教会领受恩典。",
            source: source,
            sourceLanguage: "en",
            targetLanguage: "zh-Hans"
        )
        #expect(issues.contains(.implausibleLength))
    }

    @Test func shortScriptureAndCodeSwitchingTranslationsRemainPlausible() {
        let scripture = fidelityIssues(
            target: "Read John 3:16.",
            source: "请读约翰福音3章16节。"
        )
        let codeSwitching = fidelityIssues(
            target: "我们宣告 Jesus is Lord，并在基督里同心。",
            source: "We declare that Jesus is Lord and remain united in Christ.",
            sourceLanguage: "en",
            targetLanguage: "zh-Hans"
        )
        #expect(!scripture.contains(.implausibleLength))
        #expect(!codeSwitching.contains(.implausibleLength))
    }

    @Test func faithfulLongTranslationRemainsPlausible() {
        let source =
            "圣灵在教会中工作，使信徒明白真理、彼此相爱、忠心祷告，并在日常生活中"
            + "见证耶稣基督的恩典与复活的大能。"
        let target =
            "The Holy Spirit works in the church, enabling believers to understand the truth, "
            + "love one another, pray faithfully, and testify in daily life to the grace of "
            + "Jesus Christ and the power of His resurrection."
        #expect(!fidelityIssues(target: target, source: source).contains(.implausibleLength))
    }

    @Test func truncatedSafetyFallbackIsShownWithBackendLengthFlag() async throws {
        let source =
            "她在教会的聚会和日常生活中忠心服事众人，用温柔和忍耐扶持软弱的肢体，"
            + "恒切地为圣徒祷告，清楚传扬耶稣基督的福音，并鼓励每一位信徒在恩典中"
            + "一同成长，彼此相爱，建立基督的身体，向周围的人见证主丰富的生命。"
        let target = "She served faithfully and encouraged the church to follow Christ together."
        let harness = try await makeTranslationHarness(
            responses: [.success(source), .success(source), .success(target)]
        )
        defer { harness.model.remove() }

        let result = try await harness.provider.translate(safetyFallbackRequest(source))

        #expect(result.targetText == target)
        #expect(
            result.review?.issueCodes
                == ["quality.implausible_length", "quality.pronoun_alignment"]
        )
    }

    private func fidelityIssues(
        target: String,
        source: String,
        sourceLanguage: String = "zh-Hans",
        targetLanguage: String = "en"
    ) -> [OutputValidationIssue] {
        HyMT2FidelityValidator.issues(
            target: target,
            source: source,
            requiredTerms: [],
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
    }
}

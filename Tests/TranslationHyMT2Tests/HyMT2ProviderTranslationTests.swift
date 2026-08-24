import Testing
import TranslationAPI
@testable import TranslationHyMT2

@MainActor
@Suite struct HyMT2ProviderTranslationTests {
    @Test func translatesWithOnlyApplicableGlossaryTerms() async throws {
        let harness = try await makeTranslationHarness(responses: [
            .success("We receive justification by faith through grace.")
        ])
        defer { harness.model.remove() }
        let request = TranslationRequest(
            sourceText: "我们因信称义，这是恩典。",
            glossary: [
                TranslationTerm(source: "因信称义", target: "justification by faith"),
                TranslationTerm(source: "恩典", target: "grace"),
                TranslationTerm(source: "洗礼", target: "baptism"),
            ]
        )

        let result = try await harness.provider.translate(request)

        #expect(
            result.targetText
                == "We receive justification by faith through grace."
        )
        #expect(result.sourceText == request.sourceText)
        let prompts = await harness.transport.completionRequests().map(\.prompt)
        #expect(prompts.count == 1)
        #expect(prompts[0].contains("因信称义 翻译成 justification by faith"))
        #expect(!prompts[0].contains("洗礼"))
    }

    @Test func validationFailureGetsExactlyOneStrictRetry() async throws {
        let harness = try await makeTranslationHarness(responses: [
            .success("We are made right."),
            .success("We receive justification by faith through grace."),
        ])
        defer { harness.model.remove() }
        let request = TranslationRequest(
            sourceText: "我们因信称义，这是恩典。",
            glossary: [
                TranslationTerm(source: "因信称义", target: "justification by faith"),
                TranslationTerm(source: "恩典", target: "grace"),
            ]
        )

        let result = try await harness.provider.translate(request)

        #expect(result.targetText.contains("justification by faith"))
        let prompts = await harness.transport.completionRequests().map(\.prompt)
        #expect(prompts.count == 2)
        #expect(
            await harness.transport.completionRequests().allSatisfy {
                $0.stopSequences == [HyMT2PromptControlDelimiter.currentSourceClosing]
            }
        )
        #expect(prompts[0].contains("不得概括、添加或漏译"))
        #expect(prompts[1].contains("不得概括、添加或漏译"))
        #expect(!prompts[0].contains("保留所有数字、专名、明确否定和指定术语"))
        #expect(prompts[1].contains("保留所有数字、专名、明确否定和指定术语"))
    }

    @Test func transportFailureDoesNotTriggerContentRetry() async throws {
        let harness = try await makeTranslationHarness(responses: [
            .failure(.transportFailure("connection reset")),
            .success("Unused response"),
        ])
        defer { harness.model.remove() }
        let request = TranslationRequest(sourceText: "恩典", glossary: [])

        do {
            _ = try await harness.provider.translate(request)
            Issue.record("Expected transport failure")
        } catch let error as HyMT2Error {
            #expect(error == .transportFailure("connection reset"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        let requestCount = await harness.transport.completionRequests().count
        #expect(requestCount == 1)
    }

    @Test func rejectsEmptySourceWithoutCallingRuntime() async throws {
        let harness = try await makeTranslationHarness(responses: [])
        defer { harness.model.remove() }

        do {
            _ = try await harness.provider.translate(
                TranslationRequest(sourceText: "  \n", glossary: [])
            )
            Issue.record("Expected empty source error")
        } catch let error as TranslationProviderError {
            guard case .emptySource = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        let requests = await harness.transport.completionRequests()
        #expect(requests.isEmpty)
    }

}

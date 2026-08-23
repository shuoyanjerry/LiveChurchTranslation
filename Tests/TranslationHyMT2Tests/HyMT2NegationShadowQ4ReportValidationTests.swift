import Foundation
import Testing

@Suite("Hy-MT2 negation shadow report integrity")
struct NegationShadowQ4ReportTests {
    @Test("hashes raw UTF-8 bytes deterministically")
    func hashesRawOutput() {
        #expect(
            HyMT2NegationShadowFileHasher.sha256UTF8("abc")
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    @Test("requires output hashes for passes and output-validation failures")
    func rejectsMissingOutputHashes() {
        #expect(throws: HyMT2NegationShadowQ4ReportError.invalidResult) {
            try encoded(status: .passed, failureCode: nil, outputSHA256: nil)
        }
        #expect(throws: HyMT2NegationShadowQ4ReportError.invalidResult) {
            try encoded(
                status: .failed,
                failureCode: "neg.shadow.semantic.anchor",
                outputSHA256: nil
            )
        }
    }

    @Test("requires nil output hash only for pre-output transport failure")
    func validatesTransportHashState() throws {
        #expect(throws: HyMT2NegationShadowQ4ReportError.invalidResult) {
            try encoded(
                status: .failed,
                failureCode: "neg.shadow.transport",
                outputSHA256: validOutputHash
            )
        }
        _ = try encoded(
            status: .failed,
            failureCode: "neg.shadow.transport",
            outputSHA256: nil
        )
    }

    @Test("rejects malformed output hashes")
    func rejectsMalformedOutputHash() {
        #expect(throws: HyMT2NegationShadowQ4ReportError.invalidHash) {
            try encoded(status: .passed, failureCode: nil, outputSHA256: "not-a-hash")
        }
    }

    private var validOutputHash: String {
        HyMT2NegationShadowFileHasher.sha256UTF8("public output")
    }

    private func encoded(
        status: HyMT2NegationShadowQ4Status,
        failureCode: String?,
        outputSHA256: String?
    ) throws -> Data {
        let result = HyMT2NegationShadowQ4Result(
            fixtureID: "one.not",
            encoding: "englishNot",
            occurrenceCount: 1,
            status: status,
            failureCode: failureCode,
            latencyMilliseconds: 1,
            outputSHA256: outputSHA256
        )
        return try HyMT2NegationShadowQ4ReportWriter.encoded(
            HyMT2NegationShadowQ4Report(environment: environment, results: [result])
        )
    }

    private var environment: HyMT2NegationShadowQ4Environment {
        HyMT2NegationShadowQ4Environment(
            modelURL: URL(fileURLWithPath: "/public/model.gguf"),
            helperURL: URL(fileURLWithPath: "/public/helper"),
            reportURL: URL(fileURLWithPath: "/public/report.json"),
            modelSHA256: HyMT2NegationShadowQ4Settings.expectedModelSHA256,
            helperSHA256: HyMT2NegationShadowQ4Settings.expectedHelperSHA256
        )
    }
}

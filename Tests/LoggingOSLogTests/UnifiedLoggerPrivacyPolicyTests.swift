import Foundation
import LoggingAPI
@testable import LoggingOSLog
import Testing

@Suite struct UnifiedLoggerPrivacyPolicyTests {
    @Test func payloadKeepsMessageAndSortedMetadataInsideOnePrivateField() {
        let record = LogRecord(
            level: .info,
            category: "Session",
            message: "private transcript",
            metadata: ["speaker": "private name", "session": "private identifier"]
        )

        #expect(
            UnifiedLogPayload(record).text
                == "private transcript [session=private identifier speaker=private name]"
        )
    }

    @Test func sourceHasOnePrivateInterpolationAndNoPublicDynamicPayload() throws {
        let repository = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repository.appending(path: "Sources/LoggingOSLog/UnifiedLogger.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(!source.contains("privacy: .public"))
        #expect(source.components(separatedBy: "privacy: .private").count - 1 == 1)
    }
}

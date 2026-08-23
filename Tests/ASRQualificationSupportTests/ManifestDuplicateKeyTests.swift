import ASRQualificationSupport
import Foundation
import Testing

@Suite struct ManifestDuplicateKeyTests {
    private let decoder = ASRQualificationManifestDecoder()

    @Test func rejectsDuplicateRootKeyBeforeFoundationCollapsesIt() {
        let data = Data(#"{"schemaVersion":2,"schemaVersion":3}"#.utf8)

        expectError(
            .duplicateJSONField(path: "$", field: "schemaVersion"),
            data: data
        )
    }

    @Test func rejectsEscapedEquivalentObjectKeys() {
        let data = Data(#"{"outer":{"id":1,"\u0069\u0064":2}}"#.utf8)

        expectError(
            .duplicateJSONField(path: "$.outer", field: "id"),
            data: data
        )
    }

    @Test func rejectsDuplicateKeysAtArbitraryArrayDepth() {
        let data = Data(#"{"outer":[{"value":1,"value":2}]}"#.utf8)

        expectError(
            .duplicateJSONField(path: "$.outer[0]", field: "value"),
            data: data
        )
    }

    private func expectError(_ expected: ASRQualificationError, data: Data) {
        do {
            _ = try decoder.decode(data)
            Issue.record("Expected \(expected)")
        } catch let error as ASRQualificationError {
            #expect(error == expected)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

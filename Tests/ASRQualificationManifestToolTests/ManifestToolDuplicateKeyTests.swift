import Foundation
import Testing

@Suite struct ManifestToolDuplicateKeyTests {
    @Test func rejectsEscapedEquivalentDuplicateBeforeFoundationParsing() {
        let data = Data(#"{"schemaVersion":1,"schema\u0056ersion":2}"#.utf8)

        #expect(
            throws: ManifestToolError.duplicateJSONField(
                source: "vad",
                path: "$",
                field: "schemaVersion"
            )
        ) {
            _ = try StrictJSONShape.rootObject(data, source: "vad")
        }
    }

    @Test func rejectsDeepDuplicateInsideArrayObject() {
        let data = Data(#"{"outer":[{"inner":{"id":1,"id":2}}]}"#.utf8)

        #expect(
            throws: ManifestToolError.duplicateJSONField(
                source: "corpus",
                path: "$.outer[0].inner",
                field: "id"
            )
        ) {
            _ = try StrictJSONShape.rootObject(data, source: "corpus")
        }
    }

    @Test func validDeepObjectsStillReachShapeParsing() throws {
        let data = Data(#"{"outer":[{"inner":{"id":1}}]}"#.utf8)

        let root = try StrictJSONShape.rootObject(data, source: "reference")

        #expect(root["outer"] != nil)
    }
}

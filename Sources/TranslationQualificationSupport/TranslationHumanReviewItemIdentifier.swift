import Foundation

enum HumanReviewItemIdentifier {
    static func make(
        _ identity: HumanReviewRequirementIdentity,
        binding: TranslationHumanReviewReportBinding
    ) -> String {
        var data = Data("TRANSLATION-HUMAN-REVIEW-ITEM-V1\0".utf8)
        let values = [
            binding.reportSHA256, binding.manifestSHA256, binding.attemptIdentitySHA256,
            identity.sourceID, String(identity.sequence), identity.segmentID,
            identity.kind.rawValue, identity.subject,
        ]
        for value in values { append(Data(value.utf8), to: &data) }
        return TranslationQualificationSHA256.hash(data: data)
    }

    private static func append(_ value: Data, to output: inout Data) {
        var size = UInt64(value.count).bigEndian
        Swift.withUnsafeBytes(of: &size) { output.append(contentsOf: $0) }
        output.append(value)
    }
}

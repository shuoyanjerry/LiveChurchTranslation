import TranslationQualificationSupport

enum DiscourseQualificationGate {
    static func requireNoHardFailures(
        _ report: DiscourseQualificationReport
    ) throws {
        let count = report.aggregate.hardFailureCount
        guard count == 0 else {
            throw TranslationQualificationError.invalidReport(
                "discourse qualification hard failure count: \(count)"
            )
        }
    }
}

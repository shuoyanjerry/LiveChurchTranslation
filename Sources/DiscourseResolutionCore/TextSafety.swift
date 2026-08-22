import DiscourseResolutionAPI

enum TextSafety {
    private static let quotationMarks: Set<Character> = [
        "\"", "'", "“", "”", "‘", "’", "「", "」", "『", "』", "《", "》",
    ]

    static func blockingConstraints(in text: String) -> [DiscourseResolutionConstraint] {
        var constraints: [DiscourseResolutionConstraint] = []
        if text.contains(where: quotationMarks.contains) {
            constraints.append(.quotationProtected)
        }
        if text.contains("神") || text.contains("祂") {
            constraints.append(.deityReferenceProtected)
        }
        if ["他们", "她们", "他們", "她們", "他俩", "她俩"].contains(where: text.contains) {
            constraints.append(.pluralReferenceProtected)
        }
        return constraints
    }
}

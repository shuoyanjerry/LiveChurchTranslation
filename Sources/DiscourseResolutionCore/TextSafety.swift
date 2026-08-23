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
        let pluralForms = [
            "他们", "她们", "它们", "祂们", "他們", "她們", "它們", "祂們",
            "他俩", "她俩", "它俩", "祂俩",
        ]
        if pluralForms.contains(where: text.contains) {
            constraints.append(.pluralReferenceProtected)
        }
        return constraints
    }
}

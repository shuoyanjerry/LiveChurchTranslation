/// Replaceable boundary for conservative cross-utterance source-text resolution.
public protocol DiscourseResolving: Sendable {
    func resolve(_ request: DiscourseResolutionRequest) -> DiscourseResolutionResult
}

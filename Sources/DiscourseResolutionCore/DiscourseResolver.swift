import DiscourseResolutionAPI

/// A stateless, deterministic resolver for narrowly supported Mandarin pronouns.
public struct DiscourseResolver: DiscourseResolving {
    public init() {}

    public func resolve(_ request: DiscourseResolutionRequest) -> DiscourseResolutionResult {
        ResolutionEngine(request: request).resolve()
    }
}

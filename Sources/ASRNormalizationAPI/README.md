# ASRNormalizationAPI

- **Purpose:** Defines the replaceable Mandarin ASR text-normalization boundary.
- **Public API:** Immutable `ASRNormalizationRule` and `ASRTextNormalizer`.
- **Dependencies:** None; this module is pure Swift.
- **Threading model:** Values are `Sendable`; implementations must be safe for concurrent use.
- **Failure modes:** The protocol is total and returns the original text when no rule applies.
- **Tests:** Contract behavior is exercised by `ASRNormalizationCoreTests` and session tests.

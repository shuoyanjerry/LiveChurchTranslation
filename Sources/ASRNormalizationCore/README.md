# ASRNormalizationCore

- **Purpose:** Performs deterministic, literal Mandarin ASR phrase correction.
- **Public API:** `RuleBasedASRTextNormalizer`, implementing `ASRTextNormalizer`
  and preserving original text plus every applied correction.
- **Dependencies:** `ASRNormalizationAPI` only.
- **Threading model:** Stateless value implementation; calls are concurrency-safe.
- **Failure modes:** Empty, whitespace-only, duplicate, and no-op rules are ignored safely.
- **Tests:** Built-ins, user rules, longest-match precedence, and non-cascading behavior.

Rules are matched against the original input from longest alias to shortest. User rules
precede built-ins when aliases collide. Replacements never cascade into later rules.

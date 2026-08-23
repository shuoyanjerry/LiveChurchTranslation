# ASR Qualification Text Metrics

## Public API

`ASRQualificationTextMetrics.normalizedStrictCER(reference:hypothesis:)` returns
the exact Levenshtein edit count, normalized-reference character count, and CER.
`normalizedEdgeFreeSemiglobalCER(reference:hypothesis:)` returns the same fields
while making only a hypothesis prefix and suffix free. The complete reference
must still align, so missing or changed reference text remains charged.

`normalizedStrictPronounConfusion(reference:hypothesis:)` reports observed
`(reference: String?, hypothesis: String?)` pair counts plus reference,
hypothesis, correct, substitution, deletion, and insertion totals for `他`,
`她`, `它`, and `祂`. A `nil` side represents a deletion or insertion. Pair
counts are sorted deterministically with `nil` first, followed by the four
pronouns in the order above. All three result types are immutable `Codable`,
`Hashable`, and `Sendable` values; the encoded CER measurement includes its
derived `rate`.

All APIs first lowercase the input and then retain only characters for which
Swift reports `isLetter` or `isNumber`. Pronoun confusion is derived from the
full normalized strict character alignment; it never aligns a projected
pronoun-only sequence.

## Failures and Edge Cases

The functions are pure and nonthrowing. A strict empty normalized reference
still reports its exact insertion count. Its rate is zero when the edit count is
zero and one otherwise. Under the edge-free policy, an all-hypothesis input is
an uncharged edge and therefore has zero edits and rate zero.

Strict backtrace resolves equal-cost choices deterministically: diagonal
(match or substitution), then reference deletion, then hypothesis insertion.
Preferring a local diagonal substitution over gaps prevents displaced identical
pronouns from being reported as a false correct match.

## Complexity

Both CER policies use deterministic dynamic programming with `O(r * h)` time
and `O(r * h)` space for normalized reference length `r` and hypothesis length
`h`. Strict pronoun confusion adds `O(r + h)` alignment traversal and at most
24 distinct observed pronoun/nil pair categories.

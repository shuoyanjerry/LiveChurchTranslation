# DiscourseResolutionCore

`DiscourseResolver` is a stateless, deterministic implementation. When one
explicit referent is unique, it may correct the first eligible singular `他` /
`她` subject at a sentence boundary or after a small connector set. It never
propagates that evidence to later candidates in the same request. An earlier
object pronoun blocks later repair rather than letting a proposal object become
the subject by mistake.

Evidence is limited to the documented female and male appellations. A unique
current-turn anchor before the pronoun wins; otherwise exactly one anchor may be
drawn from verified sequence `current - 1` or `current - 2`. Two mentions remain
ambiguous even when both have the same gender. Names and occupations never count.

The resolver abstains around mixed `他` / `她` candidate spellings, quotations,
plurals, deity references, lexical occurrences such as `他人` / `其他` / `吉他`,
non-boundary pronouns, invalid context ordering, stale context, and request
windows larger than two turns. An anchor after a candidate pronoun is not
allowed to retroactively identify it.

Confidence is a policy score, not a model probability: current-turn evidence is
`1.0`, the immediately preceding verified turn is `0.9`, and a two-turn-old
verified turn is `0.8`.

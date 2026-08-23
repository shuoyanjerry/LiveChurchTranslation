# DiscourseResolutionCore

`DiscourseResolver` is a stateless, deterministic implementation. When one
explicit referent is unique, it may correct the first eligible singular `他` /
`她` / `祂` subject at a sentence boundary or after a small connector set. It never
propagates that evidence to later candidates in the same request. An earlier
object pronoun blocks later repair rather than letting a proposal object become
the subject by mistake.

Evidence is limited to documented female/male appellations and explicit Christian
deity terms. A unique current-turn anchor before the pronoun wins. Multiple
preceding current-turn, singular human anchors may provide gender-only evidence
when every anchor shares one gender; anchors appearing after the candidate are
never evidence or blockers for that candidate. Exact identity remains
unspecified. Persisting a prior turn does not confirm co-reference, so prior
human or deity appellations never authorize rewriting a later `他` / `她`.
Prior context remains available for order, quotation, plural, and competing-anchor
abstention. Deity is a distinct referent class, never biological male. Names and
occupations never count as human-gender evidence.

The resolver abstains around mixed candidate spellings, quotations, plurals,
ambiguous deity references, lexical occurrences such as `他人` / `其他` / `吉他`,
non-boundary pronouns, invalid context ordering, stale context, and request
windows larger than two turns. A lone anchor after a candidate cannot identify
it; uniform multi-anchor evidence communicates only a gender category and never
claims exact referent identity.

Recognizer gender/deity glyphs are unresolved by default; their spelling is not
evidence. This includes `祂`. `它` stays outside this resolver until a separately
qualified human-versus-nonhuman referent binder exists; forcing it through the
human singular-they policy would corrupt legitimate nonhuman references. Qualified
current-turn human evidence can therefore repair a mistaken `祂` glyph too.
One unique qualified `神` / `上帝` / `耶稣` / `基督` / `主耶稣` / `圣灵`
anchor before it in the current turn, or in bounded prior context, may classify
that unchanged glyph as verified deity. Only a qualified current-turn anchor may
audit a safe `他` / `她` → `祂` repair. Bare `主` is never an anchor. Bare `神`
requires a clause boundary plus a small referential continuation allowlist;
compounds such as `神父`, `神经`, `神学`, `精神`, and `门神` do not qualify.

Human appellations also require a lexical start or an allowlisted referential
lead-in such as `那位` / `一位` / `我的`. Product and event compounds such as
`母亲节`, `父亲节`, `女士衬衫`, and `男人装` are not people and never become
gender anchors.

Confidence is a policy score, not a model probability. Current-turn evidence is
`1.0`. Scores `0.9` and `0.8` apply only when a one- or two-turn-old qualified
deity anchor classifies an already-written `祂`; those scores never permit a
cross-turn text correction.

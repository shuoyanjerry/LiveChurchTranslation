# DiscourseResolutionAPI

This target is the immutable boundary for conservative Mandarin pronoun repair.
It has no dependency on session, transcript, UI, or model-runtime types.
`DiscourseResolving` makes the implementation replaceable through dependency
injection.

`DiscourseResolutionRequest` carries the current sequence and text plus at most
two preceding persisted, validator-approved turns. Persistence proves storage
and translation success, not co-reference confirmation. Sequence numbers are
part of the contract: the implementation applies a two-turn TTL and does not
infer recency from array position.

Every correction retains the original and replacement text, a UTF-16 range in
the original string, a typed reason and confidence, and the exact evidence turn.
An unchanged result can report both semantic ambiguities and policy constraints,
so an abstention remains inspectable.

Every observed `他` / `她` / `它` / `祂` also receives occurrence-level immutable
guidance. A decision is unresolved spoken Mandarin, verified male/female human,
or verified Christian-deity identity with its reason, confidence, and evidence
turn. Deity identity is not represented as biological male. No recognizer glyph,
including `祂`, is evidence by itself. `祂` receives verified-deity guidance only
when a separate, qualified deity anchor occurs before it in the current turn or
in bounded prior context; qualified current human evidence may instead repair it
as a human pronoun. Prior context can classify an already-written `祂`, but cannot
authorize rewriting `他` / `她` / `它`. Unchanged source does not erase an
unresolved decision.

The API intentionally has no person, name, occupation, or inferred-identity
model. Only explicit evidence is accepted by the Core implementation.
An implementation can report that additional candidates were protected instead
of silently propagating evidence that was established for only one candidate.

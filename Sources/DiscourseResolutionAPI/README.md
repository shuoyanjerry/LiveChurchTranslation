# DiscourseResolutionAPI

This target is the immutable boundary for conservative Mandarin pronoun repair.
It has no dependency on session, transcript, UI, or model-runtime types.
`DiscourseResolving` makes the implementation replaceable through dependency
injection.

`DiscourseResolutionRequest` carries the current sequence and text plus at most
two preceding persisted, validator-approved turns. Sequence numbers are part of the contract:
the implementation applies a two-turn TTL and does not infer recency from array
position.

Every correction retains the original and replacement text, a UTF-16 range in
the original string, a typed reason and confidence, and the exact evidence turn.
An unchanged result can report both semantic ambiguities and policy constraints,
so an abstention remains inspectable.

The API intentionally has no person, name, occupation, or inferred-identity
model. Only explicit evidence is accepted by the Core implementation.
An implementation can report that additional candidates were protected instead
of silently propagating evidence that was established for only one candidate.

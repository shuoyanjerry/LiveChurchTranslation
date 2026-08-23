# DiscourseResolutionCoreTests

The suite exercises current-turn female, male, and deity evidence,
uniform-gender evidence across multiple explicit human anchors, post-connector
correction, first-edit-only behavior, explicit protection of later candidates,
and UTF-16 audit ranges. Cross-turn storage context is verified to abstain from
human/deity text correction because persistence is not co-reference confirmation.

Abstention coverage includes competing and same-gender multiple entities, mixed
candidate spellings, quotation, plural, lexical `他` occurrences, competing
human/deity references, object position, proposal direction, stale and invalid
sequence context, oversized windows, and the prohibition on guessing gender
from a name or occupation. Deity tests cover evidence-bound and unresolved `祂`,
bounded prior deity classification without repair, Christian titles, and ordinary
`主` / `神` compound false positives. Human-anchor tests reject lexical and
product compounds including `母亲节`, `父亲节`, `女士衬衫`, and `男人装`.

After the three Package targets are registered, run:

```sh
swift test --filter DiscourseResolutionCoreTests
```

## Private bilingual qualification

The environment-gated qualification lane replays the frozen bilingual sermon
manifest through the production `DiscourseResolver`; it does not load an ASR
or translation model. Turns remain isolated by source and each completed
resolver output enters the same rolling two-turn source context used by the
Hy-MT qualification runner.

Set `BILINGUAL_TRANSLATION_MANIFEST` to the frozen manifest and set
`DISCOURSE_QUALIFICATION_REPORT` to a filename (not a path) to opt in. The
optional `TRANSLATION_QUALIFICATION_WORKSPACE_ROOT` selects the workspace.
Reports are atomically written with private permissions under
`.artifacts/discourse-qualification/`.

The report contains only corpus/source/segment/occurrence IDs, counts, policy
classes, and SHA-256 hashes. It contains no sermon, reference, antecedent, or
resolved text. A generated automatic gender/deity class that disagrees with the
manifest is a hard failure; missed resolvable cases and safe abstentions remain
visible as separate metrics.

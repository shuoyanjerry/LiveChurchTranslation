# DiscourseResolutionCoreTests

The suite exercises positive female and male carry-over, current-turn priority,
post-connector correction, first-edit-only behavior, explicit protection of
later candidates, and UTF-16 audit ranges.

Abstention coverage includes competing and same-gender multiple entities, mixed
`他` / `她` candidate spellings, quotation, plural, lexical `他` occurrences,
deity references, object position, proposal direction, stale and invalid
sequence context, oversized windows, and the prohibition on guessing gender
from a name or occupation.

After the three Package targets are registered, run:

```sh
swift test --filter DiscourseResolutionCoreTests
```

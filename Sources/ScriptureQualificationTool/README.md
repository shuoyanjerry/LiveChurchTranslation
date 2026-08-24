# ScriptureQualificationTool

## Purpose

Provides the command-line preflight used by the ephemeral private Scripture qualification workflow. It
validates a caller-owned corpus through `ScriptureQualificationSupport`; it does not run ASR or translation,
publish a report, copy corpus material, or grant redistribution rights.

## Public API

None. The executable accepts exactly:

```text
scripture-qualification-tool verify <private-root> <manifest> <expected-sha256>
```

On success it prints only the corpus identifier and aggregate item/pair counts.

## Dependencies

`ScriptureQualificationSupport`, Foundation for arguments and file access, and Darwin for process exit.

## Threading Model

The tool is a synchronous one-shot process. The support library owns validation semantics; no background
task or persistent service is created.

## Failure Modes

Invalid usage, containment, permissions, manifest structure, hashes, declared use, or corpus identity fail
closed, emit one `preflight failed` diagnostic to standard error, and return a nonzero status. Private
corpus text is not printed.

## Tests

`ScriptureQualificationSupportTests` covers the strict loader and
`Scripts/test_ephemeral_scripture_qualification.sh` covers success, preflight failure, signal cleanup, and
the wrapper's ephemeral lifecycle.

# OpenClaw Memory Configuration (QMD Backend)

This document captures the memory settings currently applied in this OpenClaw setup so future sessions can reference one canonical config.

## Goal

Use QMD as the memory backend for better retrieval quality and tighter token control.

## Applied Config Snippet

```json
{
  "memory": {
    "backend": "qmd",
    "citations": "auto",
    "qmd": {
      "searchMode": "query",
      "includeDefaultMemory": true,
      "update": {
        "interval": "5m",
        "debounceMs": 15000,
        "waitForBootSync": false,
        "embedInterval": "30m"
      },
      "limits": {
        "maxResults": 6,
        "maxSnippetChars": 700,
        "maxInjectedChars": 4200,
        "timeoutMs": 8000
      }
    }
  }
}
```

## What Each Setting Does

- `memory.backend: "qmd"`
  - Switches memory search from builtin SQLite manager to QMD sidecar.

- `memory.citations: "auto"`
  - Adds source path hints in results when appropriate.

- `memory.qmd.searchMode: "query"`
  - Uses QMD combined retrieval mode (query expansion + reranking path).

- `memory.qmd.includeDefaultMemory: true`
  - Indexes default memory files:
    - `MEMORY.md`
    - `memory/**/*.md`

- `memory.qmd.update.interval: "5m"`
  - Runs periodic index refresh every 5 minutes.

- `memory.qmd.update.embedInterval: "30m"`
  - Runs periodic embedding refresh every 30 minutes.

- `memory.qmd.update.waitForBootSync: false`
  - Does not block startup waiting for initial QMD sync.

- `memory.qmd.update.debounceMs: 15000`
  - Debounces rapid file changes for 15 seconds.

- `memory.qmd.limits.maxResults: 6`
  - Caps recall result count.

- `memory.qmd.limits.maxSnippetChars: 700`
  - Caps per-result snippet size.

- `memory.qmd.limits.maxInjectedChars: 4200`
  - Caps total injected recall text in prompt assembly.

- `memory.qmd.limits.timeoutMs: 8000`
  - Caps memory search execution time.

## Operational Notes

- Config is applied via `gateway config.patch`; OpenClaw restarts automatically (SIGUSR1).
- Keep local docs retrieval in place for OpenClaw docs:
  - Collection: `openclaw-docs`
  - Root: `./openclaw-docs/docs`

## Recommended Retrieval Habit

For OpenClaw usage/config questions, prefer:

1. `qmd search "<topic>" -c openclaw-docs -n 5 --files`
2. `qmd get qmd://openclaw-docs/<path>.md`

Then answer using retrieved docs.

# MEMORY.md

## OpenClaw Docs Retrieval Preference

- When user asks about OpenClaw operations, commands, config, behavior, or architecture, first run QMD search/query in the local `openclaw-docs` collection (rooted at `./openclaw-docs/docs`) before answering.
- Prefer retrieval over stuffing long docs into context to reduce token usage.
- Helpful commands:
  - `qmd search "<topic>" -c openclaw-docs -n 5 --files`
  - `qmd get qmd://openclaw-docs/<path>.md`

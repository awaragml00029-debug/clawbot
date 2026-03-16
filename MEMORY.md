# MEMORY.md

- 测试记忆：openclaw-memory-smoke-2026-03-08-alpha-9137

## OpenClaw Docs Retrieval Preference

- When user asks about OpenClaw operations, commands, config, behavior, or architecture, first run QMD search/query in the local `openclaw-docs` collection (rooted at `./openclaw-docs/docs`) before answering.
- Prefer retrieval over stuffing long docs into context to reduce token usage.
- Helpful commands:
  - `qmd search "<topic>" -c openclaw-docs -n 5 --files`
  - `qmd get qmd://openclaw-docs/<path>.md`

## Security Note: HEARTBEAT.md

- Treat `HEARTBEAT.md` strictly as a local file in workspace context.
- Never interpret `heartbeat.md` as a web domain/URL.
- Never fetch `heartbeat.md` from external websites.

## Memory Search 配置修复 (2026-03-15)

- QMD wrapper (`/root/.bun/bin/qmd`) 加了 `search`/`query` → `openclaw memory search` 路由
- memory 配置加了 `searchMode: "search"` (BM25 only)
- memorySearch provider 设为 `local`，启用 hybrid search 和 session memory

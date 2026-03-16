# Tavily Search Skill

Use Tavily API for web search — fast, accurate, AI-optimized search results.

## When to Use

- User asks to search the web / look something up
- Need current information, news, facts
- Research tasks requiring multiple sources
- Any question that benefits from fresh web data

## Setup

Set your Tavily API key as environment variable:

```bash
export TAVILY_API_KEY="tvly-xxxxx"
```

Or pass it directly via `--api-key` flag.

## Usage

### Basic Search

```bash
python3 SKILL_DIR/scripts/tavily_search.py "your search query"
```

### Options

| Flag | Description | Default |
|------|-------------|---------|
| `--api-key KEY` | Tavily API key (overrides env var) | `$TAVILY_API_KEY` |
| `--max-results N` | Number of results (1-20) | `5` |
| `--search-depth` | `basic` or `advanced` | `basic` |
| `--include-answer` | Include AI-generated answer | off |
| `--include-raw` | Include raw HTML content | off |
| `--topic` | `general` or `news` | `general` |
| `--days N` | Recency filter (days) for news | none |
| `--include-domains` | Comma-separated allowlist | none |
| `--exclude-domains` | Comma-separated denylist | none |

### Examples

```bash
# Simple search
python3 SKILL_DIR/scripts/tavily_search.py "latest AI news"

# News search, last 3 days, with AI answer
python3 SKILL_DIR/scripts/tavily_search.py "OpenAI announcements" \
  --topic news --days 3 --include-answer

# Advanced search, 10 results, specific domains only
python3 SKILL_DIR/scripts/tavily_search.py "protein folding breakthroughs" \
  --search-depth advanced --max-results 10 \
  --include-domains "nature.com,science.org"

# With explicit API key
python3 SKILL_DIR/scripts/tavily_search.py "quantum computing" --api-key "tvly-xxxxx"
```

## Output Format

Returns JSON with:
- `answer` — AI-generated summary (if `--include-answer`)
- `results[]` — array of search results, each with:
  - `title` — page title
  - `url` — source URL
  - `content` — extracted text snippet
  - `score` — relevance score (0-1)
  - `raw_content` — full HTML (if `--include-raw`)

## Integration Notes

- **SKILL_DIR** should be resolved to the absolute path of this skill's directory
- The script uses only `urllib` (stdlib) — no pip dependencies needed
- API rate limits: free tier = 1,000 searches/month
- Advanced search costs more credits but returns better results

## Troubleshooting

- `TAVILY_API_KEY not set` → export the env var or use `--api-key`
- `401 Unauthorized` → check your API key is valid
- `429 Too Many Requests` → rate limited, wait or upgrade plan

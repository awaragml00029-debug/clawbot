#!/usr/bin/env python3
"""Tavily Search API wrapper.

Usage:
    python3 tavily_search.py "your query" [--depth basic|advanced] [--max-results N] [--include-answer] [--include-raw-content] [--topic general|news|finance]

Environment:
    TAVILY_API_KEY - Required. Your Tavily API key.
"""

import argparse
import json
import os
import sys
import urllib.request
import urllib.error

API_URL = "https://api.tavily.com/search"


def search(
    query: str,
    api_key: str,
    search_depth: str = "basic",
    max_results: int = 5,
    include_answer: bool = False,
    include_raw_content: bool = False,
    topic: str = "general",
    include_domains: list = None,
    exclude_domains: list = None,
) -> dict:
    payload = {
        "api_key": api_key,
        "query": query,
        "search_depth": search_depth,
        "max_results": max_results,
        "include_answer": include_answer,
        "include_raw_content": include_raw_content,
        "topic": topic,
    }
    if include_domains:
        payload["include_domains"] = include_domains
    if exclude_domains:
        payload["exclude_domains"] = exclude_domains

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        API_URL,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"HTTP {e.code}: {body}", file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"Request failed: {e.reason}", file=sys.stderr)
        sys.exit(1)


def format_results(data: dict) -> str:
    lines = []

    if data.get("answer"):
        lines.append("## Answer")
        lines.append(data["answer"])
        lines.append("")

    results = data.get("results", [])
    if not results:
        lines.append("No results found.")
        return "\n".join(lines)

    lines.append(f"## Results ({len(results)})")
    lines.append("")

    for i, r in enumerate(results, 1):
        title = r.get("title", "Untitled")
        url = r.get("url", "")
        content = r.get("content", "")
        score = r.get("score", 0)

        lines.append(f"### {i}. {title}")
        lines.append(f"**URL:** {url}")
        lines.append(f"**Relevance:** {score:.2f}")
        lines.append("")
        lines.append(content)
        lines.append("")

        if r.get("raw_content"):
            lines.append("<details><summary>Raw content</summary>")
            lines.append("")
            lines.append(r["raw_content"][:2000])
            lines.append("")
            lines.append("</details>")
            lines.append("")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Search the web via Tavily API")
    parser.add_argument("query", help="Search query")
    parser.add_argument("--depth", choices=["basic", "advanced"], default="basic",
                        help="Search depth (default: basic)")
    parser.add_argument("--max-results", type=int, default=5,
                        help="Max results (default: 5)")
    parser.add_argument("--include-answer", action="store_true",
                        help="Include AI-generated answer")
    parser.add_argument("--include-raw-content", action="store_true",
                        help="Include raw page content")
    parser.add_argument("--topic", choices=["general", "news", "finance"], default="general",
                        help="Search topic (default: general)")
    parser.add_argument("--include-domains", nargs="+", default=None,
                        help="Only include these domains")
    parser.add_argument("--exclude-domains", nargs="+", default=None,
                        help="Exclude these domains")
    parser.add_argument("--json", action="store_true",
                        help="Output raw JSON instead of formatted text")

    args = parser.parse_args()

    api_key = os.environ.get("TAVILY_API_KEY")
    if not api_key:
        print("Error: TAVILY_API_KEY environment variable not set.", file=sys.stderr)
        sys.exit(1)

    data = search(
        query=args.query,
        api_key=api_key,
        search_depth=args.depth,
        max_results=args.max_results,
        include_answer=args.include_answer,
        include_raw_content=args.include_raw_content,
        topic=args.topic,
        include_domains=args.include_domains,
        exclude_domains=args.exclude_domains,
    )

    if args.json:
        print(json.dumps(data, indent=2, ensure_ascii=False))
    else:
        print(format_results(data))


if __name__ == "__main__":
    main()

#!/usr/bin/env bash
# QMD wrapper - provides qmd CLI interface for openclaw memory backend
# Searches memory files directly using grep (BM25-like keyword matching)

set -euo pipefail

MEMORY_DIR="${OPENCLAW_WORKSPACE:-/root/.openclaw/workspace}"

case "${1:-}" in
    search|query)
        shift
        # Parse args
        MAX_RESULTS=6
        QUERY=""
        JSON_OUTPUT=false
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -n|--max-results) MAX_RESULTS="$2"; shift 2 ;;
                -c|--agent|--collection) shift 2 ;;  # ignored, we search all memory
                --json) JSON_OUTPUT=true; shift ;;
                -*) shift ;;  # skip unknown flags
                *) QUERY="$1"; shift ;;
            esac
        done

        if [[ -z "$QUERY" ]]; then
            echo "[]"
            exit 0
        fi

        # Search memory files with grep, output JSON array
        # Search MEMORY.md and memory/*.md
        RESULTS="[]"
        COUNT=0

        # Build list of files to search
        FILES=()
        [[ -f "$MEMORY_DIR/MEMORY.md" ]] && FILES+=("$MEMORY_DIR/MEMORY.md")
        for f in "$MEMORY_DIR"/memory/*.md; do
            [[ -f "$f" ]] && FILES+=("$f")
        done

        # Split query into words for matching
        IFS=' ' read -ra WORDS <<< "$QUERY"

        RESULTS="["
        FIRST=true
        for file in "${FILES[@]}"; do
            [[ $COUNT -ge $MAX_RESULTS ]] && break

            # Check if file contains any query word (case-insensitive)
            MATCHED=false
            for word in "${WORDS[@]}"; do
                if grep -qi "$word" "$file" 2>/dev/null; then
                    MATCHED=true
                    break
                fi
            done

            if $MATCHED; then
                # Extract matching context (up to 700 chars)
                REL_PATH="${file#$MEMORY_DIR/}"
                # Get lines matching any query word, with context
                SNIPPET=""
                for word in "${WORDS[@]}"; do
                    MATCH=$(grep -i -m 3 -B1 -A2 "$word" "$file" 2>/dev/null | head -20)
                    if [[ -n "$MATCH" ]]; then
                        SNIPPET="$SNIPPET$MATCH\n"
                    fi
                done
                # Truncate to 700 chars and escape for JSON
                SNIPPET=$(echo -e "$SNIPPET" | head -15 | cut -c1-700)
                SNIPPET_JSON=$(echo "$SNIPPET" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))")

                if ! $FIRST; then
                    RESULTS="$RESULTS,"
                fi
                FIRST=false
                RESULTS="$RESULTS{\"path\":\"$REL_PATH\",\"snippet\":$SNIPPET_JSON,\"score\":0.5}"
                COUNT=$((COUNT + 1))
            fi
        done
        RESULTS="$RESULTS]"
        echo "$RESULTS"
        ;;

    embed|index)
        shift
        # No-op for now (embedding requires API key)
        echo '{"status":"ok","message":"index skipped (no embedding API)"}'
        ;;

    status)
        shift
        FILES=$(find "$MEMORY_DIR" -name "*.md" -path "*/memory/*" -o -name "MEMORY.md" 2>/dev/null | wc -l)
        echo "{\"status\":\"ok\",\"files\":$FILES,\"backend\":\"grep\"}"
        ;;

    *)
        echo "Usage: qmd {search|query|embed|index|status} [args]" >&2
        exit 1
        ;;
esac

#!/bin/bash
# QMD wrapper that calls openclaw memory commands
# Translates qmd-style flags to openclaw memory search flags

case "$1" in
    embed)
        shift
        exec openclaw memory index "$@"
        ;;
    search|query)
        shift
        # Translate qmd flags to openclaw memory search flags
        args=()
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -n)
                    args+=("--max-results" "$2")
                    shift 2
                    ;;
                -c)
                    args+=("--agent" "$2")
                    shift 2
                    ;;
                *)
                    args+=("$1")
                    shift
                    ;;
            esac
        done
        exec openclaw memory search "${args[@]}"
        ;;
    status)
        shift
        exec openclaw memory status "$@"
        ;;
    "collection"|"update"|"add")
        echo "qmd wrapper: ignoring $*"
        exit 0
        ;;
    *)
        echo "qmd wrapper: unsupported command: $1"
        exit 1
        ;;
esac

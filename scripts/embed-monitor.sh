#!/bin/bash
# QMD Embed Monitor v2 - crash-resilient, small batches
# Strategy: run embed with --batch-size 1, auto-restart on crash
# Kill and restart every 3 minutes to prevent memory buildup

LOCK_FILE="/tmp/qmd-embed.lock"
LOG_FILE="/tmp/qmd-embed-monitor.log"
MAX_RUN_SECONDS=180  # kill embed every 3 min to prevent OOM/segfault
COOLDOWN=10          # seconds between restarts

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"; }

check_pending() {
    openclaw memory status 2>/dev/null | grep -i 'Pending:' | grep -oP '\d+' | head -1 || echo "?"
}

log "=== Monitor v2 started ==="

while true; do
    PENDING=$(check_pending)
    log "CHECK: pending=$PENDING"

    # Done?
    if [ "$PENDING" = "0" ]; then
        log "ALL DONE: no pending chunks!"
        echo "{\"time\":\"$(date -Iseconds)\",\"pending\":\"0\",\"complete\":true}" > /tmp/qmd-embed-status.json
        break
    fi

    # Can't read status?
    if [ "$PENDING" = "?" ]; then
        log "WARN: can't read pending count, retrying in 30s"
        sleep 30
        continue
    fi

    # Run embed with timeout to prevent memory buildup
    log "START: openclaw memory index --verbose (timeout ${MAX_RUN_SECONDS}s)"
    timeout $MAX_RUN_SECONDS openclaw memory index --verbose >> "$LOG_FILE" 2>&1
    # Also force embed of workspace files
    log "FORCE EMBED: indexing workspace files"
    find /root/.openclaw/workspace -name "*.md" -type f -newer /tmp/qmd-last-run 2>/dev/null | wc -l >> "$LOG_FILE" 2>&1
    touch /tmp/qmd-last-run
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        log "DONE: embed batch completed successfully"
    elif [ $EXIT_CODE -eq 124 ]; then
        log "TIMEOUT: killed after ${MAX_RUN_SECONDS}s (normal, prevents memory buildup)"
    elif [ $EXIT_CODE -eq 139 ] || [ $EXIT_CODE -eq 134 ]; then
        log "CRASH: segfault/abort (exit $EXIT_CODE), restarting after cooldown"
    else
        log "ERROR: exit code $EXIT_CODE, restarting after cooldown"
    fi

    # Write status for heartbeat
    NEW_PENDING=$(check_pending)
    echo "{\"time\":\"$(date -Iseconds)\",\"pending\":\"$NEW_PENDING\",\"lastExit\":$EXIT_CODE}" > /tmp/qmd-embed-status.json
    log "STATUS: pending now=$NEW_PENDING (was $PENDING)"

    # Cooldown before next run
    sleep $COOLDOWN
done

log "=== Monitor v2 finished ==="

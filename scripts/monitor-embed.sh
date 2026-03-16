#!/bin/bash
# Monitor QMD embed process
# - Check if embed is running
# - If crashed, restart it
# - Log status

LOG="/root/.openclaw/workspace/scripts/embed-monitor.log"
REPORT_INTERVAL=10800  # 3 hours in seconds

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

check_embed() {
  # Check if qmd embed is running
  if pgrep -f "qmd embed" > /dev/null 2>&1; then
    return 0  # running
  else
    return 1  # not running
  fi
}

restart_embed() {
  log "Restarting qmd embed..."
  cd /root/.openclaw/agents/main/qmd
  nohup /root/.bun/bin/qmd embed --batch-size 8 >> "$LOG" 2>&1 &
  sleep 2
  if check_embed; then
    log "Embed restarted successfully (PID: $(pgrep -f 'qmd embed'))"
  else
    log "ERROR: Failed to restart embed"
  fi
}

log "=== Monitor started ==="

last_report=0

while true; do
  now=$(date +%s)

  if check_embed; then
    log "Embed running OK (PID: $(pgrep -f 'qmd embed'))"
  else
    # Check if it finished successfully
    if /root/.bun/bin/qmd status 2>/dev/null | grep -q "unembedded: 0"; then
      log "Embed completed! All chunks embedded. Monitor exiting."
      echo "DONE" > /root/.openclaw/workspace/scripts/embed-status.txt
      exit 0
    else
      log "Embed not running and not finished. Restarting..."
      restart_embed
    fi
  fi

  # Report every 3 hours
  elapsed=$((now - last_report))
  if [ "$elapsed" -ge "$REPORT_INTERVAL" ]; then
    status=$(/root/.bun/bin/qmd status 2>/dev/null | head -20)
    log "=== 3-HOUR REPORT ===\n$status\n=== END REPORT ==="
    echo "$status" > /root/.openclaw/workspace/scripts/embed-status.txt
    last_report=$now
  fi

  sleep 300  # check every 5 minutes
done

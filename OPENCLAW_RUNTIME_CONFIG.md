# OpenClaw Runtime Config Snapshot

This file records the currently applied OpenClaw tuning so it can be reused quickly.

## Memory (QMD backend)

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

## Agent/runtime tuning

```json
{
  "agents": {
    "defaults": {
      "contextPruning": {
        "mode": "cache-ttl",
        "ttl": "5m"
      },
      "compaction": {
        "mode": "safeguard",
        "memoryFlush": {
          "enabled": true,
          "softThresholdTokens": 6000
        }
      },
      "subagents": {
        "model": "minimax/MiniMax-M2.1",
        "maxConcurrent": 8,
        "archiveAfterMinutes": 30
      },
      "heartbeat": {
        "every": "120m",
        "activeHours": {
          "start": "08:00",
          "end": "24:00"
        }
      }
    }
  },
  "messages": {
    "inbound": {
      "debounceMs": 3000
    }
  },
  "session": {
    "reset": {
      "mode": "idle",
      "idleMinutes": 240
    }
  }
}
```

## Skills sources currently added

- `/root/.openclaw/skills/anthropics-skills/skills`
- `/root/.openclaw/skills/claude-scientific-skills/scientific-skills`
- `/root/.openclaw/skills/claude-scientific-writer/skills`

## Notes

- `agentic-data-scientist` repository is cloned locally but is not loaded as an OpenClaw Skill pack because no `SKILL.md` entrypoint was detected.

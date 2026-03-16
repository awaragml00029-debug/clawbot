# OpenClaw Memory / QMD 配置指南

> 给 AI 看的配置文件。按顺序执行即可完成 memory 系统配置。

---

## 目标

让 openclaw 的 `memory_search` 工具走本地 BM25 搜索（QMD），不依赖外部 embedding API。

## 前提

- openclaw 已安装并能运行 `openclaw gateway status`
- 配置文件位于 `~/.openclaw/openclaw.json`

---

## 第一步：配置 openclaw.json

在 `~/.openclaw/openclaw.json` 中设置以下两个部分：

### 1. `memory` 段（顶层）

```json
{
  "memory": {
    "backend": "qmd",
    "qmd": {
      "searchMode": "search",
      "includeDefaultMemory": true,
      "sessions": {
        "enabled": true
      },
      "update": {
        "interval": "5m",
        "debounceMs": 15000,
        "onBoot": true
      },
      "limits": {
        "timeoutMs": 15000
      }
    }
  }
}
```

关键字段说明：
- `backend: "qmd"` — 使用 QMD 作为记忆后端
- `searchMode: "search"` — **必须设置**，BM25 only，跳过 embedding（否则会在无 GPU 机器上跑满 CPU 超时）
- `sessions.enabled: true` — 索引 session 历史
- `update.onBoot: true` — 启动时自动索引

### 2. `agents.defaults.memorySearch` 段

```json
{
  "agents": {
    "defaults": {
      "memorySearch": {
        "provider": "local",
        "fallback": "none",
        "experimental": {
          "sessionMemory": true
        },
        "sources": ["memory", "sessions"],
        "store": {
          "vector": {
            "enabled": true
          }
        },
        "query": {
          "hybrid": {
            "enabled": true
          }
        }
      }
    }
  }
}
```

关键字段说明：
- `provider: "local"` — 不走外部 API，本地处理
- `fallback: "none"` — 不 fallback 到 OpenAI 等外部 provider
- `sources: ["memory", "sessions"]` — 搜索 memory 文件和 session 历史

---

## 第二步：QMD Wrapper 脚本

openclaw 内部会调用 `qmd query` 命令来执行搜索。需要确保 `qmd` 命令存在且能正确路由到 `openclaw memory search`。

找到 `qmd` 的位置（通常在 `~/.bun/bin/qmd` 或 `/usr/local/bin/qmd`），替换为以下内容：

```bash
#!/bin/bash
# QMD wrapper - routes qmd commands to openclaw memory
case "$1" in
    embed)
        shift
        exec openclaw memory index "$@"
        ;;
    search|query)
        shift
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
```

然后：
```bash
chmod +x <qmd路径>
```

---

## 第三步：AGENTS.md 中的使用说明

在 workspace 的 `AGENTS.md` 中加入以下内容，告诉 AI 怎么用 QMD：

```markdown
## Session Startup

**不要主动加载任何文件。** QMD (BM25) 是你的记忆系统，按需搜索即可。

- 需要回忆什么 → `qmd search "关键词"`
- 需要知道用户是谁 → `qmd search "user preferences"`
- 需要最近发生了什么 → `qmd search "recent context"`

SOUL.md、USER.md、MEMORY.md、daily notes 都已被 QMD 索引，不需要启动时全量读取。
```

---

## 第四步：重启 Gateway

```bash
openclaw gateway restart
```

---

## 验证

```bash
# 检查 QMD 状态
openclaw memory status

# 应该看到已索引的文件数和 chunk 数
# 例如：11 chunks, 3 files indexed

# 测试搜索（在 session 中用 memory_search 工具）
# memory_search(query="测试") 应该返回结果而不是 API key 错误
```

---

## 常见问题

| 问题 | 原因 | 解决 |
|------|------|------|
| `memory_search` 报 OpenAI API key 错误 | `memorySearch.provider` 没设或 fallback 到了 OpenAI | 设 `provider: "local"`, `fallback: "none"` |
| `qmd query` 报 unsupported command | wrapper 脚本缺少 `query` 路由 | 更新 wrapper，加 `search\|query` case |
| CPU 跑满超时 | 缺少 `searchMode: "search"`，跑了 embedding | 加 `searchMode: "search"` |
| CLI 调用被 scope deny | 正常，CLI 没有 session context | 在 Telegram/Discord session 中测试 |
| 搜索返回空 | 文件未索引 | 跑 `openclaw memory index --force` |

---

## 已知 Bug 参考

- openclaw #20346: `searchMode: "search"` 时仍触发 `qmd embed`，已在 `a305dfe62` 修复
- 确保 openclaw 版本 >= 2026.2.19-2 后的修复版本

# OpenClaw Memory System 部署指南

> 从零配置 OpenClaw 的 QMD 记忆系统。交给 AI 按此文档执行即可。
>
> 基于 OpenClaw v0.7.131 验证。

## 前置条件

- OpenClaw 已安装（全局 npm）
- Node.js 22+
- bun 已安装（用于 qmd）
- Gateway 已能启动

## 第一步：安装 QMD

```bash
bun install -g qmd
```

验证：
```bash
which qmd        # 应输出 /root/.bun/bin/qmd
qmd --version    # 确认可执行
```

## 第二步：QMD Wrapper 脚本

OpenClaw 调用 qmd 时期望特定的 JSON 输出格式。原始 qmd 输出缺少 `docid`、`collection`、`file` 字段。需要用 wrapper 脚本包装。

将以下脚本写入 qmd 的实际安装路径（覆盖原始入口）：

**路径**: `/root/.bun/install/global/node_modules/qmd/qmd`（即 `which qmd` 指向的实际文件）

```bash
#!/usr/bin/env bash
set -euo pipefail

QMD_REAL="$(dirname "$0")/src/cli.ts"
BUN="/root/.bun/bin/bun"

# Route subcommands
case "${1:-}" in
  search|query)
    MODE="$1"; shift
    QUERY=""
    JSON_FLAG=false
    NUM=6
    COLLECTION=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --json) JSON_FLAG=true; shift ;;
        -n) NUM="$2"; shift 2 ;;
        -c) COLLECTION="$2"; shift 2 ;;
        *) [[ -z "$QUERY" ]] && QUERY="$1" || QUERY="$QUERY $1"; shift ;;
      esac
    done
    if [[ -z "$QUERY" ]]; then
      echo "no results found"
      exit 0
    fi
    CMD_ARGS=("$MODE" "$QUERY" "-n" "$NUM")
    [[ -n "$COLLECTION" ]] && CMD_ARGS+=("-c" "$COLLECTION")
    RAW=$("$BUN" run "$QMD_REAL" "${CMD_ARGS[@]}" 2>/dev/null || true)
    if [[ -z "$RAW" ]] || echo "$RAW" | grep -qi "no results"; then
      echo "no results found"
      exit 0
    fi
    if $JSON_FLAG; then
      echo "$RAW" | "$BUN" -e "
        const lines = (await Bun.stdin.text()).trim().split('\n');
        const results = [];
        let current = null;
        for (const line of lines) {
          const docMatch = line.match(/^#([a-f0-9]+)\s+\[([^\]]+)\]\s+(.*?)\s+\(score:\s*([\d.]+)\)/);
          if (docMatch) {
            if (current) results.push(current);
            current = { docid: '#' + docMatch[1], collection: docMatch[2], file: docMatch[3], score: parseFloat(docMatch[4]), snippet: '' };
          } else if (current) {
            current.snippet += (current.snippet ? '\n' : '') + line;
          }
        }
        if (current) results.push(current);
        console.log(JSON.stringify(results));
      "
    else
      echo "$RAW"
    fi
    ;;
  collection)
    shift
    SUB="${1:-}"; shift || true
    case "$SUB" in
      add)
        COL_PATH=""; COL_NAME=""; COL_MASK=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --name) COL_NAME="$2"; shift 2 ;;
            --mask) COL_MASK="$2"; shift 2 ;;
            *) COL_PATH="$1"; shift ;;
          esac
        done
        ARGS=("collection" "add" "$COL_PATH")
        [[ -n "$COL_NAME" ]] && ARGS+=("--name" "$COL_NAME")
        [[ -n "$COL_MASK" ]] && ARGS+=("--mask" "$COL_MASK")
        "$BUN" run "$QMD_REAL" "${ARGS[@]}" 2>&1
        ;;
      list)
        "$BUN" run "$QMD_REAL" collection list 2>&1
        ;;
      remove)
        "$BUN" run "$QMD_REAL" collection remove "$@" 2>&1
        ;;
      *) "$BUN" run "$QMD_REAL" collection "$SUB" "$@" 2>&1 ;;
    esac
    ;;
  update|embed)
    "$BUN" run "$QMD_REAL" "$@" 2>&1
    ;;
  *)
    "$BUN" run "$QMD_REAL" "$@" 2>&1
    ;;
esac
```

设置权限：
```bash
chmod +x /root/.bun/install/global/node_modules/qmd/qmd
```

验证 wrapper：
```bash
qmd search "test" --json -n 3
# 应返回 JSON 数组，每项含 docid, collection, file, score, snippet
# 或 "no results found"
```

## 第三步：openclaw.json 记忆配置

在 `openclaw.json` 中添加/修改以下配置：

```json
{
  "memory": {
    "backend": "qmd",
    "citations": "auto",
    "qmd": {
      "searchMode": "search",
      "includeDefaultMemory": true,
      "sessions": {
        "enabled": true
      },
      "update": {
        "interval": "5m",
        "debounceMs": 15000,
        "onBoot": true,
        "embedInterval": "30m",
        "waitForBootSync": false
      },
      "limits": {
        "timeoutMs": 8000,
        "maxResults": 6,
        "maxSnippetChars": 700,
        "maxInjectedChars": 4200
      },
      "scope": {
        "default": "allow"
      },
      "bootstrapCollections": [
        {
          "path": "/root/.openclaw/workspace/skills",
          "name": "skills",
          "mask": "**/*.md"
        }
      ]
    }
  }
}
```

同时简化 `agents.defaults.memorySearch`（不要设 provider，QMD backend 不需要）：

```json
{
  "agents": {
    "defaults": {
      "memorySearch": {
        "sources": ["memory", "sessions"]
      }
    }
  }
}
```

## 第四步：重启 Gateway

```bash
openclaw gateway restart
```

## 第五步：验证

```bash
# 1. 检查 gateway 状态
openclaw gateway status

# 2. 检查日志无 scope denied
grep "scope denied" /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log

# 3. 检查 memory-core 插件已加载
grep "memory-core" /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log

# 4. 测试搜索（在对话中）
# 调用 memory_search 工具，应返回结果而非 disabled=true
```

## 踩坑记录

### 1. scope denied（最常见）
- **症状**: 日志 `qmd search denied by scope (channel=unknown, chatType=unknown, session=<none>)`
- **原因**: 默认 `DEFAULT_QMD_SCOPE` 是 `{ default: "deny", rules: [{ action: "allow", match: { chatType: "direct" } }] }`，session key 未传入时 chatType 解析为 unknown
- **修复**: 配置 `memory.qmd.scope: { "default": "allow" }`

### 2. 无效配置 key（被 schema 校验拒绝）
以下 key 名是**错误的**，不要使用：
- ❌ `memory.qmd.update.intervalMinutes` → ✅ `memory.qmd.update.interval`（值如 `"5m"`）
- ❌ `memory.qmd.update.embedIntervalMinutes` → ✅ `memory.qmd.update.embedInterval`（值如 `"30m"`）
- ❌ `memory.qmd.update.awaitOnBoot` → ✅ `memory.qmd.update.waitForBootSync`
- ❌ `memory.qmd.searchTimeoutMs` → ✅ `memory.qmd.limits.timeoutMs`
- ❌ `memory.searchMode` → ✅ `memory.qmd.searchMode`
- ❌ `memory.qmd.citations` → ✅ `memory.citations`

### 3. memorySearch provider
- QMD backend 不需要 embedding provider，不要设 `memorySearch.provider: "local"`
- `local` provider 需要 `node-llama-cpp`，大多数环境不可用
- 自动选择顺序：local → openai → gemini → voyage → mistral → 禁用
- 但 QMD backend 完全绕过这个，直接走 QMD CLI

### 4. QMD wrapper JSON 格式
OpenClaw 期望搜索结果包含以下字段：
- `docid` — 文档 ID（如 `#1a022b`）
- `snippet` — 文本片段
- `score` — 相关度分数
- `collection` — 集合名
- `file` — 文件路径

原始 qmd 输出只有 `path` + `snippet`，缺少其他字段。wrapper 负责解析和转换。

### 5. 混合搜索（query 模式）
- `searchMode: "search"` = 纯 BM25，毫秒级，推荐
- `searchMode: "query"` = BM25 + 向量 + 重排序，需要 node-llama-cpp GPU 支持
- 无 GPU 时 query 模式会超时，保持 search 即可
- 1000+ 文件量级下 BM25 完全够用

### 6. 文件名大小写（Linux）
- Linux 文件系统大小写敏感
- QMD SQLite 可能存储小写路径（如 `memory.md`），实际文件是大写（`MEMORY.md`）
- 这不影响搜索功能，但 `resolveDocLocation` 定位文件时可能失败

### 7. memory-core 插件
- 内置插件，自动加载，无需在 `plugins.allow` 中配置
- 位置：`/usr/lib/node_modules/openclaw/extensions/memory-core/`

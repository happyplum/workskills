---
name: opencode-subagent-log-triage
description: 当 OpenCode 的子代理、子会话、工具调用、后台任务或浏览器检查看起来卡住，需要查本地日志与 SQLite 会话库再决定是否清理进程时使用；也用于复盘某次 OpenCode 任务耗时耗费过高、统计会话树成本与 token、找出最慢或最耗资源子会话时使用。
---

# OpenCode 子代理日志排查与成本复盘

## 概述

面向 **OpenCode** 本地运行数据的两类只读取证场景，共用同一套数据源（SQLite 数据库、本地日志、Windows 进程树）：

- **卡住排查**：当界面显示子代理或工具调用一直处于运行中时，核实它是「仍在执行」「进程已结束仅状态未更新」还是「证据冲突」，再给出最小安全处理建议。
- **执行复盘**：把「这次任务又慢又贵」的体感变成清晰账单——按父子会话树汇总成本、token 与耗时，定位消耗最大的子会话。

> **铁律**：在用独立证据把卡住的 session、工具调用记录、操作系统进程树和端口归属关联清楚之前，绝不杀进程或修改任何文件。本 skill 只做取证与建议，不主动派发子代理续跑任务。

## 本地存储事实（先读）

- **SQLite 数据库是唯一权威源**：`%USERPROFILE%\.local\share\opencode\opencode.db`。`session` 表包含成本与各类 token 统计列。
- **旧 session JSON 已停更**：`storage\session\` 下的 JSON 文件在 OpenCode 迁移至 SQLite 后不再更新，发现其修改时间陈旧时直接查数据库，不要浪费时间翻旧 JSON。
- **大库只读访问**：数据库可能达数十 GB，一律只读打开（配套脚本已内置 `readOnly`），禁止 `VACUUM` 或任何写入；`opencode.db-wal` 中的最新记录会随主库自动读取，无需单独处理。
- **`cost` 列含义**：仅按量计费模型有费用数值；订阅制或免费模型的 `cost` 为 `0`，但 token 计数真实有效。复盘消耗时绝不能把 `$0` 当作零消耗，重点看 `tokens_cache_read`（通常是 `input` 的十倍量级）。
- **日志与工具输出路径**：日志在 `%USERPROFILE%\.local\share\opencode\log`；工具输出在 `%USERPROFILE%\.local\share\opencode\tool-output`。

## 可接受的排查起点

用户提供以下任意线索即可开始排查：
- Session ID：`ses_...`
- 后台任务 ID：`bg_...`
- 消息或 part ID：`msg_...`、`prt_...`
- 工具描述或子会话标题关键词（例如某次浏览器检查或命令描述）
- 项目路径或 worktree 路径
- 端口号、进程名、URL 或浏览器 session 名

如果用户只给了文字描述，先用有辨识度的子串检索。工具描述通常存在 `part` 表的 JSON 数据里，常规 session 标题搜索可能搜不到。

## 排查与取证流程

1. **优先尝试高层 session 查询工具**：
   - 已知 ID 时用 `session_info(session_id)`；
   - 用 `session_search(query)` 搜索标题、工具描述、目录名、URL 或端口；
   - 已知项目或 worktree 路径时用 `session_list(project_path)`。
2. **高层接口未命中或结果矛盾时，直接查本地 SQLite 数据库**（优先使用下方只读脚本）。
3. **定位真实的父子会话与工具调用 part**（关键表结构）：
   - `session(id, parent_id, title, directory, agent, model, cost, tokens_*, time_created, time_updated)`
   - `message(id, session_id, data)`
   - `part(id, message_id, session_id, time_created, time_updated, data)`
4. **提取可疑工具 part 的完整字段**：
   - `status`、`exit`、`tool`、`description`、`command`、`workdir`、`timeout`；
   - 已捕获的输出、stdout/stderr 以及最后更新时间；
   - 同一消息相邻的 `step-start` / `step-finish` 记录。
5. **关联操作系统进程与端口状态**（给出任何清理建议前必做）：
   - 核对精确的工具进程 PID、父 PID、子进程、命令行和启动时间；
   - 检查相关端口当前的监听进程 PID；
   - 明确区分 **卡住的工具进程** 与 **被测试的应用服务器**（若应用服务器通过 `long-running-process` 启动，查看 `%TEMP%\opencode-long-running\*.json` 核对归属）。
6. **判定进程存活三态**：
   - `ACTIVE`：已关联到仍存活且有持续输出或正常 CPU/IO 活动的进程；
   - `INACTIVE`：会话/工具已结束，或数据库仍标为 running 但对应进程已不存在（状态陈旧）；
   - `UNKNOWN`：数据库、日志与进程树信息冲突，或无法可靠关联到具体 PID。
7. **给出最小安全处置建议**：
   - **无需操作**：命令已结束且会话状态已关闭；
   - **继续等待 / 重试**：状态为 `ACTIVE` 且仍在产出有效输出；
   - **精确清理**：只终止已证实为孤儿的 **OpenCode 工具进程树**；被测应用服务器交由 `long-running-process` 的 `stop-background.ps1` / `cleanup-port.ps1` 处理；
   - **升级人工确认**：状态为 `UNKNOWN` 且存在误杀或数据丢失风险。

## 只读排查脚本（优先于手写 SQL）

仓库配套两个只读 Node.js 脚本（依赖 Node 22+ 内置 `node:sqlite`），避免在 PowerShell 中手写多层转义命令。

**1. 会话检索、父子会话树重建与成本总账（复盘主工具）**：

```powershell
node "<skill-dir>/scripts/query-sessions.mjs" --match <keyword> --since 2026-01-01
node "<skill-dir>/scripts/query-sessions.mjs" --root ses_<prefix>
```

每行输出 `agent / cost / in / out / cacheR / 时长 / 开始时间 / 标题`，末尾 `TOTAL` 行汇总总费用与 token。复盘耗时或费用时，先用 `--root` 拉出整棵会话树，再按 `cost`、时长和 `cacheR` 找出主要消耗源。

**2. 导出单会话的工具调用时间线（卡住排查核心）**：

```powershell
node "<skill-dir>/scripts/dump-session-parts.mjs" ses_<prefix> --last 10
node "<skill-dir>/scripts/dump-session-parts.mjs" ses_<prefix> --stuck
```

每行输出 `状态 / exit / 空闲分钟数 / 命令或描述摘要`。`--stuck` 过滤出状态不是 `completed` / `error` 的未闭合工具调用，即疑似卡住清单。

## 常用 SQLite 查询参考

当脚本不覆盖特殊排查需求时使用（务必以只读方式执行）：

```sql
-- 1. 按 ID、标题或目录查找 session
SELECT id, parent_id, title, directory, agent, model, time_created, time_updated
FROM session
WHERE id = 'ses_TARGET'
   OR title LIKE '%keyword%'
   OR directory LIKE '%project-or-worktree%';

-- 2. 列出指定父会话的子会话
SELECT id, title, agent, time_created, time_updated
FROM session
WHERE parent_id = 'ses_PARENT'
ORDER BY time_created;

-- 3. 查看目标会话的工具调用 part
SELECT id, message_id, time_created, time_updated,
       json_extract(data, '$.type') AS type,
       json_extract(data, '$.tool') AS tool,
       json_extract(data, '$.state.status') AS status,
       json_extract(data, '$.state.exit') AS exit_code,
       json_extract(data, '$.state.title') AS state_title,
       json_extract(data, '$.state.input.description') AS description
FROM part
WHERE session_id = 'ses_TARGET' AND json_extract(data, '$.type') = 'tool'
ORDER BY time_created;

-- 4. 按工具描述子串搜索 part JSON
SELECT session_id, message_id, id, time_created, time_updated, substr(data, 1, 1000)
FROM part
WHERE data LIKE '%tool-description-keyword%'
ORDER BY time_updated DESC;
```

## Windows 进程与端口核查

只按精确 PID 和命令行排查，绝不按宽泛进程名批量强杀：

```powershell
$targets = @(<pid1>, <pid2>)
Get-CimInstance Win32_Process |
  Where-Object { $targets -contains $_.ProcessId } |
  Select-Object ProcessId, ParentProcessId, Name, CreationDate, CommandLine |
  Format-List

Get-NetTCPConnection -LocalPort <port> -ErrorAction SilentlyContinue |
  Select-Object LocalAddress, LocalPort, State, OwningProcess
```

确认需要清理孤儿工具进程时，仅终止该精确 PID 树：

```powershell
taskkill /PID <exact-tool-pid> /T /F
```

执行后立即复查：确认目标工具 PID 已消失，且被测应用服务器与端口仍正常存活。

## 诊断报告格式

```text
结论：一句话说明当前状态（ACTIVE / INACTIVE / UNKNOWN）及核心依据。

定位：
- 子会话：ses_...
- 父会话：ses_...
- 异常 part：prt_...
- 工具/描述：...

证据：
- SQLite 状态：status=..., exit=..., updated=...
- 工具输出摘要：...
- 进程与端口归属：...

判断：
- 可能根因：...
- 已排除项：...

建议：
- 最小安全动作：...
- 不要触碰：...
```

## 常见误区

- **把工具描述当成会话标题搜索**：`session_search` 搜不到时，改搜 `part.data`。
- **只信 `session_read`**：有时高层接口会报找不到会话，但 `session_info` 和 SQLite 里完整存在。
- **在 `storage\session\` 旧 JSON 里反复查找近期记录**：迁移 SQLite 后 JSON 已停更，发现修改时间陈旧应立刻切到 DB。
- **在 PowerShell 里用 `node -e "..."` 嵌套写复杂查询**：引号和 `$` 极易转义出错，优先用内置脚本或写临时 `.mjs` 执行。
- **把 `cost=$0` 当作没有消耗**：订阅或免费模型不计费但 token 消耗真实，重点看 `tokens_cache_read`。
- **一刀切杀掉所有 `chrome.exe` 或 `node.exe`**：必须先核对父子 PID、命令行和端口归属，防止误杀应用服务器或用户自己的浏览器。
- **看到部分输出完整就断定任务已结束**：必须核实对应工具 `part` 的 `status` 已闭合且带有 `exit` 状态码。

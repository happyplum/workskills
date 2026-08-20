---
name: opencode-subagent-log-triage
description: 当 OpenCode 子代理、子会话、工具调用、后台任务或 Playwright 浏览器检查看起来卡住时使用——尤其是用户提供 session ID、子会话标题、工具描述、worktree 路径，或要求在决定是否终止进程前检查 OpenCode 本地日志/会话数据时。也用于执行会话审计与追溯：某次开发「费时费钱」、统计成本与 token、重建父子会话树、盘点某计划派了哪些子代理、找出最贵/最慢的会话时。
---

# OpenCode 子代理日志排查

## 概述

本 skill 覆盖两类取证，共用同一套本地数据源（SQLite DB / 日志 / 进程树）：

- **卡住排查**：把模糊的「子代理卡住」报告转化为证据，判断工具是否仍在运行还是仅存储陈旧，推荐最小安全干预。
- **执行审计**：把「这次开发费时费钱」的感受转化为总账——按会话树汇总成本/token/时长，找出烧钱贡献最大的会话，支撑 prompt 与流程改进讨论。

**核心原则**：在从独立证据关联起卡住的 session、工具调用、进程树和用户可见结果之前，绝不杀进程或编辑任何东西。

## 存储事实（先读）

- **SQLite DB 是唯一权威**：`%USERPROFILE%\.local\share\opencode\opencode.db`。会话表含成本与 token 列（见下）。
- **session JSON 已陈旧**：`storage\session\` 下的 JSON 文件自存储迁移后不再更新，只用于考古，发现其 mtime 陈旧时直接转向 DB，不要在 JSON 里反复 grep。
- **DB 可能数十 GB**：一律 readOnly 打开（脚本已内置），禁止 VACUUM/写入；WAL（`opencode.db-wal`）随主库一并可读，无需单独处理。
- **cost 列语义**：仅按量计费模型有值；订阅/免费模型 `cost=0` 但 token 计数真实。审计时 `$0 ≠ 零消耗`，`tokens_cache_read` 才是体量主力（常比 input 大 10 倍量级）。
- 日志：`%USERPROFILE%\.local\share\opencode\log`；工具输出：`%USERPROFILE%\.local\share\opencode\tool-output`。

## 收集输入

接受以下任一作为起点：

- Session ID：`ses_...`
- 后台任务 ID：`bg_...`
- 消息或 part ID：`msg_...`、`prt_...`
- 工具描述/标题，如 `Checks browser settings redirect`
- Worktree 或项目路径
- 端口、进程名、URL 或浏览器 session 名

若用户只给文字描述，先用特征子串搜索。工具描述常存储在 part JSON 内，可能不出现在常规 session 搜索结果中。

## 证据工作流

1. 优先用高层 session API：
   - 已知 ID 时用 `session_info(session_id)`
   - 用 `session_search(query)` 搜索特征标题、工具描述、worktree 名、URL 或端口
   - 已知项目/worktree 路径时用 `session_list(project_path)`
2. 若高层 API 未命中或不一致，转向本地存储（路径与语义见上节「存储事实」）。
3. 用 SQLite 识别真正的父/子 session 和工具 part（完整列清单见「SQLite 查询模式」）：
   - `session(id, parent_id, title, directory, agent, model, cost, tokens_*, time_created, time_updated)`
   - `message(id, session_id, data)`
   - `part(id, message_id, session_id, time_created, time_updated, data)`
4. 对每个可疑工具 part，提取：
   - `status`、`exit`、`tool`、`description`、`command`、`workdir`、`timeout`
   - 捕获的输出、stdout/stderr 和最后更新时间
   - 同一消息周围匹配的 `step-start`/`step-finish` part
  5. 推荐操作前先关联进程状态：
    - 找到精确的工具进程 PID、父 PID、子 PID、命令行和创建时间
    - 用拥有者 PID 检查相关端口
    - 确认哪个进程拥有应用服务器 vs 卡住的工具
    - 区分 **OpenCode tool 进程** vs **应用 server**（后者若由 long-running-process 启动，查 `%TEMP%\opencode-long-running\*.json`）
  6. 产出 **writer 三态**（供 recovery 消费；本 skill **不**调用 `task()` 续派）：
    - **ACTIVE**：已关联到仍存活且有进展（或合理 CPU/IO）的 writer/tool 进程
    - **INACTIVE**：session/tool 已结束，或 running 状态无对应活进程（陈旧存储）
    - **UNKNOWN**：DB/日志/进程树冲突，或无法关联 PID
  7. 仅在进程关联后，附加一种处置建议（仍不派发子代理）：
    - **无需操作**：命令已完成且 session 状态已关闭
    - **等待/重试**：writer=ACTIVE 且在产生输出
    - **精确清理**：仅终止已证实的 **OpenCode tool** 孤儿进程树；应用 server 用 `long-running-process` 的 `stop-background`/`cleanup-port`
    - **提级**：writer=UNKNOWN 且有数据丢失风险

## 脚本（优先于手写 SQL）

两个只读脚本覆盖最常见的取证场景，参数见各自文件头注释。PowerShell 调用：

会话检索 / 成本汇总 / 父子树重建（审计主工具）：

```powershell
node "<skill-dir>/scripts/query-sessions.mjs" --match webpath --since 2026-08-19   # 关键词+时间窗
node "<skill-dir>/scripts/query-sessions.mjs" --root ses_fe4fbef3                   # 整棵会话树+成本总账（支持前缀）
```

输出每行含 `agent / cost / in / out / cacheR / 时长 / 开始时间 / 标题`，末尾 TOTAL 行给出总成本与 token 体量。审计时先跑 `--root` 拿总账，再按 `cost`、`dur`、`cacheR` 排序找烧钱贡献者。

工具 part 时间线（卡住取证核心）：

```powershell
node "<skill-dir>/scripts/dump-session-parts.mjs" ses_fe2dd74 --last 10   # 支持会话 ID 前缀
node "<skill-dir>/scripts/dump-session-parts.mjs" ses_fe2dd74 --stuck     # 只看未闭合工具 part
```

每行含 `状态 / exit / idle 分钟数 / 命令或描述摘要`。`--stuck` 列出 status 非 completed/error 的工具 part——疑似卡住清单。

## SQLite 查询模式

脚本不覆盖时用手写查询。`session` 表关键列：`id, parent_id, title, directory, agent, model, cost, tokens_input/output/reasoning/cache_read/cache_write, time_created, time_updated`。

查找 session：

```sql
select id, parent_id, title, directory, agent, model, time_created, time_updated
from session
where id = 'ses_TARGET'
   or title like '%distinctive text%'
   or directory like '%worktree-or-project%';
```

列出子 session：

```sql
select id, title, agent, time_created, time_updated
from session
where parent_id = 'ses_PARENT'
order by time_created;
```

检查目标 session 的工具 part：

```sql
select id, message_id, time_created, time_updated,
       json_extract(data, '$.type') as type,
       json_extract(data, '$.tool') as tool,
       json_extract(data, '$.state.status') as status,
       json_extract(data, '$.state.exit') as exit_code,
       json_extract(data, '$.state.title') as state_title,
       json_extract(data, '$.state.input.description') as description
from part
where session_id = 'ses_TARGET' and json_extract(data, '$.type') = 'tool'
order by time_created;
```

按工具描述搜索 part JSON：

```sql
select session_id, message_id, id, time_created, time_updated, substr(data, 1, 1000)
from part
where data like '%distinctive tool description%'
order by time_updated desc;
```

## Windows 进程检查

用精确 PID 和命令行。不要按宽泛进程名终止。

```powershell
$targets = @(60132,26560,35088)
Get-CimInstance Win32_Process |
  Where-Object { $targets -contains $_.ProcessId } |
  Select-Object ProcessId,ParentProcessId,Name,CreationDate,CommandLine |
  Format-List

Get-NetTCPConnection -LocalPort 3104 -ErrorAction SilentlyContinue |
  Select-Object LocalAddress,LocalPort,State,OwningProcess
```

若清理有据，仅终止精确的孤儿工具 PID 树：

```powershell
taskkill /PID <exact-tool-pid> /T /F
```

立即验证工具 PID 消失且应用服务器 PID/端口仍存活。

## 报告格式

返回简洁报告，结构如下：

```text
理由：一句话说明核心依据。

定位：
- 子会话：ses_...
- 父会话：ses_...
- 卡住 part：prt_...
- 工具/描述：...

证据：
- SQLite 状态：status=..., exit=..., updated=...
- 工具输出摘要：...
- 进程/端口：...

判断：
- 根因假设：...
- 不是哪些问题：...

建议：
- 最小安全动作：...
- 不要动：...
```

## 常见错误

- **把工具描述当 session 标题**。`session_search` 未命中时搜 `part.data`。
- **只信 `session_read`**。它可能失败，即使 `session_info` 和 SQLite 有该 session。
- **在 `storage\session\` 的 JSON 里找近期会话**。存储已迁移到 SQLite，JSON 停止更新；发现 mtime 陈旧即转向 DB。
- **在 PowerShell 里写 `node -e "..."` 内联查询**。双引号与 `$` 转义在 PowerShell 下层层嵌套必然出错；改写临时 `.mjs` 文件再 `node` 执行，或直接用本 skill 的 scripts。
- **把 `cost=$0` 当作零消耗**。订阅/免费模型不计价但 token 真实；体量看 `tokens_cache_read`。
- **杀掉所有 `chrome.exe` 或所有 Playwright/浏览器自动化进程**。始终先关联父/子 PID 和命令行。
- **杀掉卡住浏览器检查正在测试的应用服务器**。清理前确认端口归属。
- **仅因捕获的输出看起来完整就认为 session 已解决**。验证工具 part 有 `status` closed 和 exit code。

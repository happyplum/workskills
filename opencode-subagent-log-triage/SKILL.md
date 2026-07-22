---
name: opencode-subagent-log-triage
description: 当 OpenCode 子代理、子会话、工具调用、后台任务或 agent-browser 检查看起来卡住时使用——尤其是用户提供 session ID、子会话标题、工具描述、worktree 路径，或要求在决定是否终止进程前检查 OpenCode 本地日志/会话数据时。
---

# OpenCode 子代理日志排查

## 概述

本 skill 把模糊的「子代理卡住」报告转化为证据：定位真正的 session/工具 part，判断工具是否仍在运行还是仅存储陈旧，并推荐最小安全干预。

**核心原则**：在从独立证据关联起卡住的 session、工具调用、进程树和用户可见结果之前，绝不杀进程或编辑任何东西。

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
2. 若高层 API 未命中或不一致，检查本地 OpenCode 存储：
   - 日志：`%USERPROFILE%\.local\share\opencode\log`
   - SQLite DB：`%USERPROFILE%\.local\share\opencode\opencode.db`
   - WAL 可能比主 DB 有更新鲜的事件：`opencode.db-wal`
   - 工具输出：`%USERPROFILE%\.local\share\opencode\tool-output`
3. 用 SQLite 识别真正的父/子 session 和工具 part：
   - `session(id, parent_id, title, directory, agent, model, time_created, time_updated)`
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
6. 仅在进程关联后，选择一种建议：
   - **无需操作**：命令已完成且 session 状态已关闭
   - **等待/重试**：进程活跃且在产生输出
   - **恢复/读取**：若抽象仍可用，用 `background_output` 或 `session_read`
   - **精确清理**：仅终止已证实的孤儿/卡住工具进程树
   - **提级**：若 DB 状态、日志和进程树冲突到有数据丢失风险

## SQLite 查询模式

用 `sqlite3 "%USERPROFILE%\.local\share\opencode\opencode.db"` 或等价只读查询路径。

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
       json_extract(data, '$.metadata.description') as description
from part
where session_id = 'ses_TARGET'
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
- **忽略 `opencode.db-wal`**。运行中的工具事件可能先出现在那里，早于正常抽象索引。
- **杀掉所有 `chrome.exe` 或所有 `agent-browser` 进程**。始终先关联父/子 PID 和命令行。
- **杀掉卡住浏览器检查正在测试的应用服务器**。清理前确认端口归属。
- **仅因捕获的输出看起来完整就认为 session 已解决**。验证工具 part 有 `status` closed 和 exit code。

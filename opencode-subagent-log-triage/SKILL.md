---
name: opencode-subagent-log-triage
description: Use when an OpenCode subagent, child session, tool call, background task, or agent-browser check appears stuck, especially when the user provides a session ID, child-session title, tool description, worktree path, or asks to inspect OpenCode local logs/session data before deciding whether to terminate a process.
---

# OpenCode Subagent Log Triage

## Overview

Use this skill to turn a vague stuck-subagent report into evidence: locate the real session/tool part, determine whether the tool is still running or only stale in storage, and recommend the smallest safe intervention.

Core principle: never kill or edit anything until the stuck session, tool call, process tree, and user-visible outcome have been correlated from independent evidence.

## Inputs to Collect

Accept any of these as starting points:

- Session ID: `ses_...`
- Background task ID: `bg_...`
- Message or part ID: `msg_...`, `prt_...`
- Tool description/title, such as `Checks browser settings redirect`
- Worktree or project path
- Port, process name, URL, or browser session name

If the user only gives prose, search by distinctive substrings first. Tool descriptions are often stored inside part JSON and may not appear in normal session search results.

## Evidence Workflow

1. Search high-level session APIs first when available:
   - `session_info(session_id)` if an ID is known.
   - `session_search(query)` for distinctive titles, tool descriptions, worktree names, URLs, or ports.
   - `session_list(project_path)` when the project/worktree path is known.
2. If high-level APIs miss the target or disagree, inspect local OpenCode storage:
   - Logs: `%USERPROFILE%\.local\share\opencode\log`
   - SQLite DB: `%USERPROFILE%\.local\share\opencode\opencode.db`
   - WAL can contain fresher events than the main DB: `opencode.db-wal`
   - Tool output: `%USERPROFILE%\.local\share\opencode\tool-output`
3. Use SQLite to identify the actual parent/child session and tool part:
   - `session(id, parent_id, title, directory, agent, model, time_created, time_updated)`
   - `message(id, session_id, data)`
   - `part(id, message_id, session_id, time_created, time_updated, data)`
4. For each suspect tool part, extract:
   - `status`, `exit`, `tool`, `description`, `command`, `workdir`, `timeout`
   - captured output, stdout/stderr, and last update time
   - matching `step-start`/`step-finish` parts around the same message
5. Correlate process state before recommending action:
   - Find exact tool process PID, parent PID, child PIDs, command line, and creation time.
   - Check relevant ports with owning PID.
   - Confirm which process owns the application server versus the stuck tool.
6. Only after process correlation, choose one recommendation:
   - No action: command completed and session state already closed.
   - Wait/retry: process is active and producing output.
   - Resume/read: use `background_output` or `session_read` if the abstraction still works.
   - Precise cleanup: terminate only the proven orphaned/stuck tool process tree.
   - Escalate: if DB state, logs, and process tree conflict in a way that risks data loss.

## SQLite Query Patterns

Use `sqlite3 "%USERPROFILE%\.local\share\opencode\opencode.db"` or an equivalent read-only query path.

Find a session:

```sql
select id, parent_id, title, directory, agent, model, time_created, time_updated
from session
where id = 'ses_TARGET'
   or title like '%distinctive text%'
   or directory like '%worktree-or-project%';
```

List child sessions:

```sql
select id, title, agent, time_created, time_updated
from session
where parent_id = 'ses_PARENT'
order by time_created;
```

Inspect tool parts in a target session:

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

Search part JSON by tool description:

```sql
select session_id, message_id, id, time_created, time_updated, substr(data, 1, 1000)
from part
where data like '%distinctive tool description%'
order by time_updated desc;
```

## Windows Process Checks

Use exact PIDs and command lines. Do not terminate by broad process name.

```powershell
$targets = @(60132,26560,35088)
Get-CimInstance Win32_Process |
  Where-Object { $targets -contains $_.ProcessId } |
  Select-Object ProcessId,ParentProcessId,Name,CreationDate,CommandLine |
  Format-List

Get-NetTCPConnection -LocalPort 3104 -ErrorAction SilentlyContinue |
  Select-Object LocalAddress,LocalPort,State,OwningProcess
```

If cleanup is justified, terminate the exact orphaned tool PID tree only:

```powershell
taskkill /PID <exact-tool-pid> /T /F
```

Immediately verify the tool PID disappeared and the application server PID/port remains alive.

## Report Format

Return a concise report in this shape:

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

## Common Mistakes

- Treating a tool description as a session title. Search `part.data` when `session_search` misses it.
- Trusting `session_read` alone. It may fail even when `session_info` and SQLite have the session.
- Ignoring `opencode.db-wal`. Fresh running tool events can be visible there before normal abstractions index them.
- Killing all `chrome.exe` or all `agent-browser` processes. Always correlate parent/child PIDs and command lines first.
- Killing the app server that the stuck browser check was testing. Confirm port ownership before cleanup.
- Calling a session resolved just because captured output looks complete. Verify the tool part has `status` closed and an exit code.

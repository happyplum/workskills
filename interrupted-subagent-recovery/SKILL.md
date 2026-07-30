---
name: interrupted-subagent-recovery
description: 当子代理或控制器被中断（Ctrl+C、超时、session 错误、background task 失败）后，用户说"继续"、"resume"、"超时后继续"、"Ctrl+C 后继续"或需从中断的 subagent session 恢复执行时按需加载
---

# 子代理中断恢复

## 概述

中断后直接用原始 prompt 开新子代理会丢失进度并可能在同一点再卡住。本 skill **唯一负责**恢复派发决策：发现并审计旧状态 → 证明 single-writer 与副作用可续 → `HOLD` / `CONTINUE_*` / `NEW`。

**共享 invariant（派发前）**：旧 writer 已证实停止；外部副作用不是 `unknown`；残留资源已证明可复用、已停止或不存在。证据不足 → `HOLD`，禁止第二个 writer。

## 强制规则

| # | 规则 | 验证 |
|---|------|------|
| 1 | **必须先发现旧 session**：不凭记忆假设 session_id；用 `session_list`/`session_search`/git 日志 | 已执行会话发现 |
| 2 | **必须审计 workspace + 副作用 + writer**：`session_read`/`background_output`/`git status`/`git diff`；writer 与残留按路由表取证 | 审计清单已执行；writer ∈ {ACTIVE,INACTIVE,UNKNOWN} |
| 3 | **派发前 single-writer gate**：ACTIVE 或 UNKNOWN 不得 `task()`；先等待、triage 或停残留 | 无并行第二 writer |
| 4 | **续派必须携带恢复上下文**：`[PREVIOUS-PROGRESS]` + `[DO-NOT-REPEAT]` + 四字段约束；不得复用原始 prompt | prompt 含上述段 |

## 路由（本 skill 唯一派发）

| 域 | Owner | 本 skill 做什么 | 不做什么 |
|---|---|---|---|
| writer / session 状态不明 | `opencode-subagent-log-triage` | 要 `ACTIVE`/`INACTIVE`/`UNKNOWN` 证据 | 不让 triage 调用 `task()` |
| 应用 dev server / 端口 / RunId | `long-running-process` | 要 stop/cleanup/ready 证据后再派发 | 不手写 taskkill 清应用 |
| agent-browser / Chrome | `agent-browser-windows` | 需要时路由清理浏览器域 | 不清应用端口、不决定续派 |
| 最终 `task()` | **本 skill** | `HOLD` / `CONTINUE_*` / `NEW` | — |

## 恢复协议

### 步骤 0：会话发现

1. `session_list(from_date=…, limit=10)` + `session_search(query=关键词)`
2. 找到 → 步骤 1；未找到 → workspace 现实（`git log`/`git status`/产物/端口/RunId state）为唯一真相

### 步骤 1：审计

1. **tool / TODO**：completed vs running/error；计划步骤实际状态
2. **workspace**：`git status`/`git diff`/产物；diff 可能混用户编辑，交叉 mtime，模糊则问用户
3. **writer**：session 显示 running ≠ 真有 writer。不确定时加载 triage，只接受三态结论
4. **副作用**：对 migration/push/发布/付款等标 `committed` / `rolled-back` / `unknown`
5. **残留**：端口、`%TEMP%\opencode-long-running\*.json`、后台 `bg_…`——记录后按路由表处理，不默认忽略
6. **并发**：同级子代理仍写共享资源则合并进度，不并行重派

### 步骤 2：恢复上下文

```
[PREVIOUS-PROGRESS]
Previous subagent session: <session_id or none>
Status: INTERRUPTED at "<step>"
Completed steps:
  - … — DONE (evidence: …)
Failed/Interrupted step:
  - … — FAILED/INTERRUPTED
    Command/Error/Fix required: …
Writer: ACTIVE|INACTIVE|UNKNOWN (evidence: …)
Side effects: <name>=committed|rolled-back|unknown
Residual: <RunId/port/bg/…>
Resume checkpoint: <step or file>
[/PREVIOUS-PROGRESS]

[DO-NOT-REPEAT]
- <already done with evidence>
[/DO-NOT-REPEAT]

[CONTINUATION-CONSTRAINTS]
Resume checkpoint: <…>
Allowed writes: <paths/modules>
Side effects already committed: <…>
Resources to reuse/stop: <RunId/port/none>
[/CONTINUATION-CONSTRAINTS]
```

### 步骤 3：决策（可验证）

| 决策 | 条件 | 动作 |
|---|---|---|
| **HOLD** | writer=ACTIVE/UNKNOWN，或任一侧作用=unknown，或残留归属不清 | 不调用 `task()`；等待 / triage / 外部核对 / 按路由 stop |
| **CONTINUE_SYNC** | 同目标+同 workspace；session 可 `session_info`/`session_read`；writer=INACTIVE；agent 仍适合 | 默认同步 `task(task_id="ses_…")`。**terminal/completed 不否决** |
| **CONTINUE_BACKGROUND** | 旧 `bg_…` 仍被 manager 识别且**不是** running | `task`/`background` 续接；manager 报 Task not found 或 running 拒绝 → 改 HOLD/NEW |
| **NEW** | session 不可寻址，或 continuation **显式拒绝**，或目标/角色已变 | 新 `task(...)`，仍带旧 ses id（若有）与完整恢复上下文 |

删除「完成不足 30% 则重来」——用 **可验证 checkpoint** 与 **副作用状态** 决定起点，不用完成比例。

续派 prompt 遵守六段委托契约；`[CONTEXT]`/`[REQUEST]` 含原始目标与上述三段。

## 反例

| ❌ | ✅ |
|---|---|
| 无审计直接 `task(prompt=原始任务)` | 先发现 session → 审计 → 决策表 |
| session 显示 running 就续派 | writer 未证 INACTIVE → HOLD；需要时 triage |
| 假定 terminal session 不能 `task_id` | 默认可 CONTINUE_SYNC；仅不可寻址或显式拒绝才 NEW |
| readiness 失败后立刻再 start server | 先 `stop-background`/`cleanup-port` 或证明可复用 |
| triage 里直接 `task()` 恢复 | triage 只出三态；本 skill 派发 |
| 副作用 unknown 时 NEW 重做 migration | HOLD，先查外部系统 |

```
# ✅ 决策骨架
# writer=INACTIVE, side effects known, session 可寻址
task(task_id="ses_xxx", prompt="[CONTEXT]: … [PREVIOUS-PROGRESS]: …\n[GOAL]: …\n[STOP WHEN]: …\n[EVIDENCE]: …\n[DOWNSTREAM]: …\n[REQUEST]: [DO-NOT-REPEAT]: … [CONTINUATION-CONSTRAINTS]: …")
```

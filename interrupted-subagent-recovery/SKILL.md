---
name: interrupted-subagent-recovery
description: 当子代理或控制器被中断（Ctrl+C、超时、session 错误）后用户说"继续"时按需加载。必须先审计旧执行状态再决定续派策略
---

# 子代理中断恢复

## 概述

子代理被中断或超时终止后，直接用原始 prompt 开新子代理会导致已完成工作全部丢失，且大概率在同一位置再次卡住。本 skill 规范中断后恢复前的必选流程：发现并审计旧状态 → 构建恢复上下文 → 决策续派或重做。

## 加载条件

按需加载——检测到触发词（如「继续」「resume」「中断后继续」）时由控制器主动加载，不列入会话启动必载列表。

| 使用 | 不使用 |
|------|--------|
| 用户说"继续"且上一个子代理被中断/超时/报错 | 已有恢复上下文的正常续派（`task_id` 续传） |
| 控制器自身被中断后在新会话中恢复 | 子代理正常完成后的下一个任务 |

## 强制规则

| # | 规则 | 验证 |
|---|------|------|
| 1 | **必须先发现旧 session**：不凭记忆假设 session_id；通过 `session_list`/`session_search`/git 日志找到旧执行记录 | 已执行会话发现 |
| 2 | **必须审计 workspace 现实**：通过 `session_read`/`background_output`/`git status`/`git diff` 核对已完成工作、产出完整性与残留信号（文件、端口、后台任务） | 审计清单已执行 |
| 3 | **续派必须携带恢复上下文**：prompt 含 `[PREVIOUS-PROGRESS]` + `[DO-NOT-REPEAT]`；不得复用原始 prompt | prompt 含两个段且非原始复用 |

## 恢复协议

### 步骤 0：会话发现（无旧 session_id 时）

1. `session_list(from_date=<中断日期>, limit=10)` + `session_search(query="<任务关键词>")` 查找旧会话
2. 找到 → 步骤 1；未找到 → 回退 workspace 现实（`git log`/`git status`/产物/端口扫描），这是唯一真相来源

### 步骤 1：审计旧状态

通过 `session_read`/`background_output` 检查（后台任务不轮询，等系统通知）：

1. **tool call 状态**：已完成（completed）/ 卡住或失败（running/error）
2. **TODO 完成度**：对比原计划标注实际状态
3. **workspace 现实**：`git status`/`git diff`/新建修改文件/测试产物/日志。`git diff` 可能混合子代理与用户编辑，交叉引用时间戳与 mtime，模糊时询问用户
4. **残留信号**：端口占用、后台任务状态——作为环境信号记录；具体清理按需路由
5. **并发检查**（并行调度）：枚举同级子代理，确认无同级仍写入共享资源；存活则合并进度

### 步骤 2：构建恢复上下文

```
[PREVIOUS-PROGRESS]
Previous subagent session: <session_id>
Status: INTERRUPTED at step "<step name>"
Completed steps:
  - Step 1: <description> — DONE (evidence: <files/git commits>)
  - Step 2: <description> — DONE (evidence: <output summary>)
Failed/Interrupted step:
  - Step 3: <description> — FAILED/INTERRUPTED
    Command: <exact command that failed>
    Error: <error message or "interrupted by user">
    Fix required: <what the new subagent should do differently>
Residual signals: <port/PID/background markers>
Resume from: Step 3
[/PREVIOUS-PROGRESS]

[DO-NOT-REPEAT]
- Step 1: <already done, files at ...>
- Step 2: <already done, output: ...>
[/DO-NOT-REPEAT]
```

### 步骤 3：决策与续派

| 条件 | 决策 |
|------|------|
| 卡住步骤可修复（超时、端口冲突等环境信号） | 续派，携带恢复上下文 |
| 已完成步骤占比 < 30% 且无有用产出 | 重新开始（保留对原失败原因的认知） |
| 产出不可靠（部分写入文件） | 审计完整性，必要时清理后重做 |

续派 prompt 必须包含：原始任务描述 + `[PREVIOUS-PROGRESS]` + `[DO-NOT-REPEAT]`（来自步骤 2）+ `[CONTINUATION-CONSTRAINTS]`（跳过已完成步骤、避免重复失败）。

## 反例

```
# ❌ 无脑续派 — 丢失所有已完成工作
task(category="quick", prompt="[CONTEXT]: Run QA screenshots\n[GOAL]: Capture all\n[RETURN]: paths")

# ❌ 假设 session_id 存在 — 全新会话中无旧 ID
session_read(session_id="ses_from_memory")

# ❌ 轮询仍在运行的后台任务
background_output(task_id="bg_still_running")
```

```
# ✅ 完整恢复流程
session_list(from_date="2026-06-19", limit=5)  → 找到 ses_xxx
session_read(session_id="ses_xxx")  → 审计 tool call、TODO、workspace
task(category="quick", prompt="[CONTEXT]: Run QA screenshots\n[PREVIOUS-PROGRESS]: ses_xxx interrupted at step 6. Steps 1-5 done. Step 6 failed: infinite polling.\n[DO-NOT-REPEAT]: Steps 1-5.\n[CONTINUATION-CONSTRAINTS]: Use bounded-wait + liveness-check launch pattern for dev server. Resume from step 6.\n[GOAL]: Capture remaining screenshots\n[RETURN]: paths")
```

## 最小 CSO 触发词

- 主要：`继续`（中断后）、`resume`、`timeout 后继续`、`Ctrl+C 后继续`、`subagent interrupted`
- 次要：`中断`、`卡住后继续`、`超时恢复`、`session_read`、`background_output`、`重新开始`

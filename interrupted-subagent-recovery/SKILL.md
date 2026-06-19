---
name: interrupted-subagent-recovery
description: 当子代理或控制器被中断（Ctrl+C、超时、session 错误）后用户说"继续"时使用——必须先审计旧执行状态再决定续派策略
---

# 子代理中断恢复

## 概述

子代理被中断或超时终止后，如果控制器直接用原始 prompt 开新子代理，已完成的工作全部丢失，新子代理从零开始并大概率在同一位置再次卡住。本 skill 规范控制器在中断后恢复工作前的必选审计流程。

## 加载条件

| 使用 | 不使用 |
|------|--------|
| 用户说"继续"且上一个子代理被中断/超时/报错 | 已有恢复上下文的正常续派（`task_id` 续传） |
| 控制器自身被中断后在新会话中恢复 | 子代理正常完成后的下一个任务 |
| 子代理因长运行进程卡住后恢复（结合 `long-running-process`） | 进程启动本身的问题——使用 `long-running-process` |

## 强制规则

| # | 规则 | 验证 |
|---|------|------|
| 1 | **必须先发现旧 session**：不能凭记忆假设 session_id；必须通过 `session_list`、`session_search` 或 git 日志找到旧执行记录 | 执行了步骤 0（会话发现） |
| 2 | **必须审计 workspace 现实**：通过 `session_read`/`background_output`/`git status`/`git diff` 检查已完成的工作、残留文件和产出完整性 | 审计清单已执行 |
| 3 | **必须检查残留进程**：端口占用、后台任务状态；通过 PID + 端口 + 命令行至少两项确认归属后再清理 | 进程检查已执行 |
| 4 | **续派必须携带 `[PREVIOUS-PROGRESS]` + `[DO-NOT-REPEAT]`**：新 prompt 包含已完成步骤和禁止重复的步骤 | prompt 含两个段 |
| 5 | **不得无脑续派原始 prompt**：跳过审计直接开新子代理 = 违规 | 原始 prompt 未被直接复用 |

## 恢复协议

### 步骤 0：会话发现（无旧 session_id 时的入口）

当控制器自身被中断，"继续"发生在全新会话中时：

1. `session_list(from_date=<中断日期>, limit=10)` 查找最近的 sessions
2. `session_search(query="<任务关键词>")` 查找旧工作记录
3. 若找到：进入步骤 1
4. 若未找到：回退到 workspace 现实——`git log --oneline -5`、`git status`、产物目录、端口扫描。这是唯一真相来源。

### 步骤 1：审计旧子代理

通过 `session_read(session_id=<old_session>)` 或 `background_output(task_id=<old_bg_id>)` 检查：

> **协调 `omo-subagent-type` 规则 7**：若旧子代理是后台任务（`bg_...`），**不要**轮询 `background_output`；等系统通知。若需检查仍在运行的后台任务，用非阻塞的端口探测或 `session_info` 代替。

1. **tool call 状态**：哪些已完成（status=completed）、哪个卡住/失败（status=running/error）
2. **TODO 完成度**：对比原计划，标注实际完成状态
3. **workspace 现实**：`git status`、`git diff`、新建/修改文件、测试产物、日志文件。注意：`git diff` 可能混合子代理和用户编辑；交叉引用时间戳与文件 mtime，模糊时询问用户。
4. **残留进程**：端口占用、后台任务状态；通过 PID + 端口 + 命令行至少两项确认归属
5. **并发检查**（仅并行调度）：若任务源自并行调度，枚举同级别子代理，验证没有同级子代理仍在写入共享资源；若存活，合并其进度而非重新运行。

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
Residual processes: <PID list with confirmation details>
Resume from: Step 3
[/PREVIOUS-PROGRESS]

[DO-NOT-REPEAT]
- Step 1: <already done, files at ...>
- Step 2: <already done, output: ...>
[/DO-NOT-REPEAT]
```

### 步骤 3：决策

| 条件 | 决策 |
|------|------|
| 卡住步骤可修复（如超时、端口冲突） | 续派，携带恢复上下文 |
| 已完成步骤占比 < 30%，无有用产出 | 重新开始（保留对原失败原因的认知） |
| 基础设施问题（端口占用、进程残留） | 先清理（`long-running-process` 模板 4），再续派 |
| 产出不可靠（部分写入的文件） | 审计产出完整性，必要时清理后重做 |

> **交叉引用 `atlas-execution-constraints`**：若恢复产出包含未完成的工作产物（部分写入的文件），不要执行原子提交。等新子代理验证完整性后再提交。

### 步骤 4：续派

新子代理 prompt 必须包含：
- 原始任务描述
- `[PREVIOUS-PROGRESS]` + `[DO-NOT-REPEAT]`（来自步骤 2）
- `[CONTINUATION-CONSTRAINTS]`：跳过已完成步骤、使用安全启动模板、避免重复失败

## 反例

```
# ❌ 无脑续派 — 丢失所有已完成工作
task(category="quick", prompt="[CONTEXT]: Run QA screenshots\n[GOAL]: Capture all\n[RETURN]: paths")

# ❌ 假设 session_id 存在 — 全新会话中无旧 ID
session_read(session_id="ses_from_memory")

# ❌ 轮询仍在运行的后台任务 — 违反 omo-subagent-type 规则 7
background_output(task_id="bg_still_running")
```

```
# ✅ 完整恢复流程
session_list(from_date="2026-06-19", limit=5)  → 找到 ses_xxx
session_read(session_id="ses_xxx")  → 审计 tool call、TODO、workspace
task(category="quick", prompt="[CONTEXT]: Run QA screenshots\n[PREVIOUS-PROGRESS]: ses_xxx interrupted at step 6. Steps 1-5 done. Step 6 failed: infinite polling.\n[DO-NOT-REPEAT]: Steps 1-5.\n[CONTINUATION-CONSTRAINTS]: Use long-running-process template 1+2 for dev server. Resume from step 6.\n[GOAL]: Capture remaining screenshots\n[RETURN]: paths")
```

## 最小 CSO 触发词

- 主要：`继续`（中断后）、`resume`、`timeout 后继续`、`Ctrl+C 后继续`、`subagent interrupted`
- 次要：`中断`、`卡住后继续`、`超时恢复`、`session_read`、`background_output`、`重新开始`

## 平台事实

| 参数 | 值 |
|------|-----|
| 适用角色 | 控制器（Sisyphus/Atlas） |
| 触发条件 | 子代理或控制器被中断后用户说"继续" |
| 依赖 skill | `long-running-process`（进程启动/清理）、`omo-subagent-type`（后台任务轮询协调） |

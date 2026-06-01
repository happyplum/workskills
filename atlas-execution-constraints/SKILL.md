---
name: atlas-execution-constraints
description: 当 Atlas 需要确定性执行治理以实现可靠的大任务执行时使用，包括验证顺序、规范化、证据纪律和提级边界（执行前或执行中）。
---

# Atlas 执行约束

## 概述

Atlas 执行时约束的权威来源。Atlas 提示保持精简；`subagent-driven-development`（SDD）处理拆分/路由/提级。自动执行路径中，计划层面的结构修复应依据 `oracle` 产出的结构化修订结果推进，而不是把手动命令名写成模型的直接执行步骤。核心原则：仅执行结构有效、可验证、有证据支撑的内容。

## 加载条件

当 Atlas 即将执行已审查的计划时加载，或在执行过程中纪律可能漂移时加载。仅在计划编写和审查在上游已完成时使用。

## 最小 CSO 触发词

主要：`atlas execute`、`Task N-V`、`execution gate`、`evidence before complete`、`normalize nested tasks`
次要：`plan-set entry exit gate`、`phase handoff`、`parent completion rule`、`review rejection loop`

## 反例（不应触发）

| 输入模式 | 原因 |
|---|---|
| 「生成计划」 / "write a plan" | 计划阶段，应使用 `writing-plans`。 |
| 「修复计划结构错误」 | 结构修复请求；自动执行路径应先请求 `oracle` 产出结构化修订指引，而不是直接调用手动命令。 |
| 「只要解释流程，不执行」 | 纯解释无需执行治理。 |
| 「单文件微小文本修正」 | 琐碎编辑无需完整约束栈。 |

## 强制规则

1. 执行前强制加载预加载链；缺少必需 skill 则停止。该停止点发生在任何 `task()` 委托、路由判断、或执行 TODO surface 展开之前。
2. 仅对已审查的现有计划执行；若缺失、矛盾或未就绪，停止并请求上游修复。
3. 可将已批准的计划转换为仅用于执行的 TODO 清单作为编排视图，但不重新定义为计划编写。
4. 编码工作始终以 `subagent-driven-development` 为执行核心；不得静默切换为顺序执行。
5. 在配对的 `Task N-V` 通过之前，不执行下游任务。
6. 在决定父任务完成前，先规范化可执行的嵌套项。
7. 结构一致性关卡失败时拒绝或退回计划；不得猜测。
8. 在完成声明和审查关卡前要求具体证据；保持执行状态可恢复。当任务边界和业务意图不变但执行复杂度上升时，允许有界运行时提级；若分解不足、路由错误超出有界提级范围、或需要变更范围，则停止并请求修复/重规划。

## 故障处理

- 头部契约缺失/矛盾 → 停止，退回计划修复。
- 验证失败 ≥2 次重跑或证据矛盾 → 提级。
- 阶段关卡证据缺失 → 保持状态不变，循环修复+重新验证。
- 文档级可修复 → 停止，并依据 `oracle` 的结构化修订结果请求计划修复。
- 任务或验证重新开启 → 重置受影响的 Phase/Wave 复选框直到恢复闭合。
- 提级会改变任务边界/意图/交付物 → 拒绝，请求修复/重规划。

## 必需预加载链

1. `omo-subagent-type` → 2. `subagent-driven-development` → 3. `atlas-execution-constraints`（本 skill）。缺少任一 → 停止并先加载。
2. 该链是 Atlas 的执行起点门禁，不是执行中可补的建议项；若在未闭合状态下已经开始委托或展开执行面，按路由失效处理并退回修复。

## 执行 Skill 头部契约

计划必须包含 `## Execution Skill Requirements` 作为额外 skill 的权威来源。Atlas 编码工作必须要求 `subagent-driven-development`；若缺失或与任务体矛盾，停止并退回计划修复。

## Plan-Set 契约

当 `*-index.md` 存在时：索引是编排权威来源和 Wave/Phase 进度视图；详细复选框真实状态保留在各阶段文件中。严格按声明顺序执行阶段；在前一阶段 `Entry Gate` 前置条件未满足前不得开始下一阶段。每阶段完成后，验证 `Exit Gate` 证据，更新 Phase 复选框，根据阶段文件真实状态重新计算 Wave 复选框。拒绝跨计划的直接 task-ID 依赖；要求阶段关卡令牌。

## 验证与关卡顺序

默认链：`Task N` → `Task N-V` → `metis`（需要时）→ `oracle`（需要时）。

- 在任何 `Task N-V` 或基于证据的完成声明前加载 `verification-before-completion`。
- Metis 发现计划级缺口 → 路由至 `oracle` 分析，然后停止并请求修复/重规划。
- `Task N-V` 失败 → 重新开启父任务，修复，获取新证据，重跑；通过后，原子提交再进入下一任务（不批量处理）。
- 缺陷修复：每个 `Task N`/`Task N-V` 对隔离一个可独立验证的缺陷，除非明确证实共享根因和共享验证面。
- 节点重新开启或 `Task N-V` 失败 → 重新计算 Phase/Wave 索引状态；2 次重跑失败或证据不明确时提级。

## 规范化协议

执行前：(1) 验证头部契约，(2) 扫描嵌套的可执行清单/列表项，(3) 新生成的格式异常项 → 拒绝并退回展平处理，(4) 遗留/可修复项 → 规范化为可追踪子任务，(5) 重跑结构一致性关卡。

嵌套项分类：复选框 → 可执行 → 规范化；动作动词（add/create/write/run/verify/update/delete/refactor/test/capture）→ 可执行 → 规范化；纯注释/列表/标签且无动作 → 保留为注释。

## 结构一致性关卡

执行任何任务前，验证以下全部条件：

- Waves/TODO/依赖/验证引用相同的任务集；所有依赖引用指向已存在的任务。
- 契约常量在任务体、QA 和验证间一致。
- 每个任务声明了 `category`/`subagent_type`，或携带有理据的延迟路由标记（`executor_judgment`/`routing_by_executor`）。
- Atlas 编码分支不能省略 `subagent-driven-development`；若计划依赖其他工作流，停止并请求修复。
- 最终验证不能声明没有实现任务的功能。

任何检查失败 → 停止并退回计划修复。

## 证据纪律

- 没有具体证据不得标记任务完成。
- 审查关卡前，在声明的 `evidence/` 路径下提供必需产物；回退至 `evidence/<plan-filename-basename>/task-n-*`。

## 有界运行时提级协议

仅在以下条件满足时使用：任务边界不变，业务意图不变，因执行复杂度（非遗漏交付物）变得更难，存在具体证据。

同一节点内允许：提升 category（如 `unspecified-low` → `unspecified-high` → `deep`）；当证据表明任务本质不同时重新路由到正确的领域 category；添加额外证据/检查点注释。

禁止：扩展范围或添加计划外交付物；用提级掩盖分解不足的任务；无证据使用贵价层；无审计记录的静默路由。

每次提级记录：`escalation_reason`、`from -> to`、`evidence`、`why_task_boundary_still_holds`、`repair_required_afterward`。若 `repair_required_afterward = true`，在当前节点证据完成后停止并请求计划修复再进入下一节点。

## 父任务完成规则

在以下任一项未完成时，父任务不得标记为完成：规范化的可执行子任务、配对的验证任务、必需的清单项。

## 审查驳回循环

当计划定义审查关卡时：(1) 附带证据运行审查者循环，(2) 若被驳回 → 按反馈修复，(3) 重新运行直到获得明确 OKAY。

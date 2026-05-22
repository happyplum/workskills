***

name: repairing-plans
description: 当执行计划存在结构缺陷需要修复时使用，包括任务 ID 图完整性、契约一致性、可执行 QA、路由模式有效性、验证闭合以及规模/分解审计。
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

# 计划修复

## 概述

现有计划的第二轮修复工作流。目标：修复计划结构、依赖真实性和验证对齐——而非重新界定产品意图。

**核心原则：** 先修复文档，再修复代码。
**执行标准：** 计划仅在所有硬关卡通过时才可安全交付 Atlas 执行。

## 强制规则

1. **修复边界**：不得重新界定产品意图。仅修复结构、依赖真实性和验证真实性。未解决的硬关卡 → `REJECT`。高影响歧义 → 先问 1-3 个定向问题；若仍不确定 → `BLOCKED_NEEDS_DECISION`；不得猜测。
2. **确定性修复流程**：在下游编辑前强制使用单一 task-ID 方案和单一契约常量集。运行确定性两轮流程（先规范化，再硬关卡重评估）。保持输出可审计，带显式关卡码和固定章节。
3. **验证隔离**：验收产物必须与实现任务隔离。验证和证据收集工作必须是独立的 `Task N-V` 节点，不得内联在 `Task N` 中。
4. **检查点与 Plan-Set 治理**：要求显式检查点和检查点级审计记录。对于 `plan-set`，每个子计划必须包含预检验证阶段，在当前阶段实现前重新验证上游输出。
5. **分解与路由纪律**：强制执行最小可独立执行的任务粒度。贵价 category（`deep`、`ultrabrain`、`visual-engineering`、`artistry`）仅保留给确实需要专业能力的工作。每个任务应声明 `category` 或 `subagent_type`；延迟路由需要 `executor_judgment`/`routing_by_executor` 并附一行理由。贵价任务应包含 `why_not_lower_cost`。
6. **用户侧防漂移锚点**：每个计划必须在顶部附近包含简洁的用户可读摘要。修复后的计划必须保留 `## User Requirement Digest` 和 `## Intent Anchor`，不得创建第二个任务事实来源。

## 故障处理

1. 缺少输入 → 仅修复确定性格式问题后停止。
2. 高影响歧义 → 问 1-3 个定向问题；若仍不确定 → `BLOCKED_NEEDS_DECISION`。
3. 规范化后关卡反复失败 → `REJECT` 并附失败关卡集。
4. 不做叙述性信心声明；仅输出可执行的判定产物。

## 提示精简契约

本 skill 是计划修复/验证的权威规则来源。Prometheus 将修复语义委托至此。共享的 SDD 拆分/路由/提级原则存储在 `subagent-driven-development` 中；本 skill 在修复期间执行这些原则而非重新定义。若提示文本与本 skill 发生漂移，本 skill 在计划修复决策中优先。不要在 Prometheus 中复制冗长的硬关卡规则块；将修复专用关卡保留在此。

## 第二轮修复模式（强制）

1. **第一轮——结构规范化**：规范化执行 skill 头部、任务 ID 和依赖图、展平嵌套可执行项、规范化验证建模（`Task N`/`Task N-V`）。
2. **第二轮——关卡重评估**：在规范化后的计划上重跑所有硬关卡；失败时输出带关卡码的 `REJECT`；仅当硬关卡失败数 = 0 时输出 `PASS`。

任何结构变更后不得跳过第二轮。

## 检查点审计模型（强制）

- `CP0——输入基线`：在规范化前确认输入契约完整性和检查点映射。
- `CP1——规范化后`：重新编译任务图和依赖闭包。
- `CP2——验证闭合`：确认 `Task N`/`Task N-V` 链接、QA 可执行性、验证范围隔离。
- `CP3——发布就绪`：最终硬关卡摘要和分解/阶段交接就绪度。

检查点审计循环：

1. 运行 CP0 → 修复确定性问题。
2. 运行 CP1 并重评估硬关卡。
3. 若任何硬关卡失败，修复确定性问题并返回 CP1。
4. CP1 通过后运行 CP2。
5. 若 CP2 失败，修复并返回 CP1。
6. 仅在 CP1 和 CP2 通过后运行 CP3。
7. 仅当 CP3 通过且硬关卡失败数为零时退出；否则输出 `REJECT`。

## 输入契约（强制）

1. **单一 task-ID 方案**——Waves、TODO、依赖矩阵、最终验证中仅使用一种方案。同一计划中不得混用点分 ID 和顺序别名。
2. **规范契约常量**在顶部附近声明一次：`interface_prefix`（API 类计划可为 `api_prefix`）、`versioning_scheme`、`evidence_root`、`primary_stack`。
3. **用户摘要**：顶部附近的 `## User-Facing Summary`，使用用户自然语言编写，包含 `Development Core` 和 `User Requirements` 作为简洁散文/列表——不是任务 ID 或路由术语。
4. **防漂移顶部章节**：`## User Requirement Digest`（保留用户的自然语言需求、约束、禁止项、当前焦点）和 `## Intent Anchor`（`Why`/`What`/`Non-Goals`/`Must Not Drift`）。若无法恢复 → 先问定向问题；仅在歧义仍存时使用 `BLOCKED_NEEDS_DECISION`。
5. **执行 skill 头部**：`## Execution Skill Requirements`——主计划和每个子计划文件（当 `decomposition_decision = plan-set` 时）必需。
6. **每任务的验证模式**：`inline` 或 `Task N-V`。共享接口（契约、基础设施、API 聚合、集成边界）必须使用 `Task N-V`。
7. **路由声明**：`category`/`subagent_type`/`skills` 使用有效枚举值。任务应声明 `category` 或 `subagent_type`；延迟路由需要 `executor_judgment`/`routing_by_executor` + 一行理由。贵价任务应声明 `why_not_lower_cost`。
8. **计划规模审计块**：`estimated_waves`、`integration_boundaries`、`size_class`（`Small`/`Medium`/`Large`/`XLarge`）、`decomposition_decision`（`single-file` 或 `plan-set`）。
9. **检查点映射**：`CP0`、`CP1`、`CP2`、`CP3`。
10. **Plan-Set 索引追踪**（当 `decomposition_decision = plan-set` 时）：
    - 索引文件为每个 Wave 和每个 Phase 暴露 Markdown 复选框。
    - 索引仅是摘要视图；详细任务复选框状态保存在阶段文件中。
    - Wave 复选框：仅当所有实现任务 + 配对的 `Task N-V` 节点完成时勾选。
    - Phase 复选框：仅当所有可执行任务 + 配对验证节点完成时勾选。
11. **子计划预检验证**（当 `decomposition_decision = plan-set` 时）：
    - 每个阶段文件必须在实现任务前包含预检验证阶段。
    - 阶段验证上游输出、未解决阻塞项和接口/契约兼容性。

计划规模规则（最高匹配级别优先）：`Small`（waves ≤2，boundaries ≤1）| `Medium`（waves=3 或 boundaries=2）| `Large`（waves 4-5 或 boundaries=3）| `XLarge`（waves>5 或 boundaries≥4）。

分解策略：`Small` 可使用 `single-file` 或 `plan-set`。`Medium`/`Large`/`XLarge` 必须使用 `plan-set`；`single-file` 无效。

Plan-Set 文件结构：子计划文件直接放在原始计划文件同一目录中。不得创建新子文件夹。原始计划文件就地转换为索引文件，保留原始文件名。阶段文件使用阶段后缀命名（如 `my-feature-plan-phase-1.md`）。

索引文件格式：`- [ ] Wave N: name` 和 `- [ ] Phase N: name`，带指向阶段文件的链接。完成后立即更新 Phase/Wave 复选框。若任何底层任务或验证节点重新开启，则重置为未勾选。

若任何必需输入缺失，仅自动修复确定性结构/格式项。对于高影响的缺失业务决策，先问定向澄清问题；若歧义仍存，输出 `BLOCKED_NEEDS_DECISION` 并停止。

## 必需检查

1. **执行 Skill 头部**——确保 `## Execution Skill Requirements` 存在。将 skill 分类为 `Always preload`、`Conditionally load`、`Task-local only`。声明条件 skill 的执行模式和选择理由。
2. **任务执行者注解**——每个任务声明 `category`/`subagent_type`，除非以 `executor_judgment`/`routing_by_executor` + 一行理由延迟。贵价任务包含 `why_not_lower_cost`。关卡：`TASK_EXECUTOR_ANNOTATION_WEAK`（省略或贵价缺理由时软警告）。
3. **用户摘要**——顶部附近的 `## User-Facing Summary`，包含 `Development Core` 和 `User Requirements`，使用简洁的用户可读语言。关卡：`USER_SUMMARY_MISSING`（缺失、缺少任一字段、或仅为执行者简写时失败）。修复：从用户请求 + 已确定范围合成；若不可恢复 → 先问问题，再 `BLOCKED_NEEDS_DECISION`。
4. **防漂移顶部章节**——顶部附近的 `## User Requirement Digest` + `## Intent Anchor`。Digest 保留用户自然语言需求/约束/禁止项；Anchor 捕获 `Why`/`What`/`Non-Goals`/`Must Not Drift`。关卡：`ANTI_DRIFT_TOP_SECTION_MISSING`（任一缺失、Digest 被重写为术语、或 Anchor 字段缺失时失败）。修复：在 Digest 中保留用户自然语言，从显式上下文提炼 Anchor；若不可恢复 → 先问问题，再 `BLOCKED_NEEDS_DECISION`。
5. **任务展平**——将可执行的嵌套列表/清单提升为 `Task N`/`Task N.a`/`Task N-V`。仅当注释、文件列表和说明性列表项不可执行时保留嵌套。关卡：`NESTED_EXECUTABLES_FOUND`（规范化后仍保留可执行嵌套项时失败）。
6. **标识符完整性**——Waves、任务列表、依赖矩阵和验证引用相同的 task ID。移除幻影依赖和缺失引用。关卡：`ID_GRAPH_MISMATCH`（重复 ID、未知 ID、幻影依赖、引用不存在的节点或混用 ID 别名时失败）。
7. **验证配对**——含验收/证据内容的实现任务需要配对的 `Task N-V` 作为独立节点（在 TODO、Wave、依赖矩阵中）。无验收内容时不需要 `Task N-V`。下游依赖在 `Task N-V` 存在时也必须依赖 `Task N-V`。关卡：`VERIFY_CLOSURE_MISSING`（下游/最终验证依赖实现输出但缺少必需验证节点时失败；`Task N-V` 必须是独立节点，不是 `Task N` 内的章节）。
8. **契约一致性**——路由前缀、命名、存储路径、功能范围在任务体、QA 和最终验证间匹配。最终验证不得声明没有实现任务的功能。关卡：`CONTRACT_DRIFT`。
9. **任务图编译**——将 Waves + TODO + 依赖矩阵 + 验证引用编译为一个图。拒绝重复 ID、未知 ID、幻影依赖、不可达的必需节点和混用 ID 别名。
10. **QA 可执行性**——每个 QA 块必须包含：`Tool`、`Preconditions`、`Commands/Inputs`、`Expected Observable`、`Evidence`。关卡：`QA_NOT_EXECUTABLE`（QA 缺少具体命令 + 可观测预期 + 证据目标时失败；拒绝纯叙述步骤。`Tool: Bash` 要求可运行命令行，不是模糊叙述）。
11. **验证闭合**——共享接口必须使用 `Task N-V`；下游/最终验证必须依赖 `Task N-V`，而非仅 `Task N`。`inline` 仅允许用于无下游消费者的非共享本地任务。修复：创建 `Task N-V` 作为独立节点并从下游消费者添加依赖边。
12. **技术栈/路由一致性**——根据实际项目技术栈和允许的枚举值验证路由。关卡：`ROUTING_SCHEMA_INVALID`（路由使用不支持的值时失败。允许的 `category`：`visual-engineering`、`ultrabrain`、`deep`、`artistry`、`quick`、`unspecified-low`、`unspecified-high`、`writing`。允许的 `subagent_type`：`explore`、`librarian`、`oracle`、`metis`、`momus`）。关卡：`STACK_MISMATCH_BLOCKING`（技术栈声明与可执行任务/QA 路径矛盾且无声明例外时失败）。
13. **嵌套可执行项关卡**——检测应作为任务节点的可执行嵌套清单/列表项。拒绝在规范化后仍将可执行嵌套工作保留为叙述的计划。
14. **计划规模审计**——存在含必需字段的 `Plan Size Audit` 块。从 `estimated_waves`/`integration_boundaries` 重新计算。关卡：`PLAN_SIZE_AUDIT_MISSING`（块缺失或声明值 ≠ 计算值时失败）。关卡：`PLAN_SET_REQUIRED`（`Medium`/`Large`/`XLarge` 但不是 `plan-set` 时失败）。
15. **并行化审计**——优先使用最小可独立执行的任务。计划/计划检查任务需要 `parallel-safe`/`serial-only` 声明。关卡：`PARALLEL_DECLARATION_MISSING`（标签缺失或 `serial-only` 缺少一行约束理由时失败）。拒绝无约束理由的强制串行执行独立任务。对于 `Medium`/`Large`/`XLarge`，验证分解为多个计划文件并带阶段级交接关卡。
16. **验证范围隔离**——实现任务不得包含验收标准、证据收集列表或交付物证明清单。这些必须仅存在于 `Task N-V` 或检查点审计块中。关卡：`VALIDATION_SCOPE_LEAK`（在实现体中发现时失败）。修复：从 `Task N` 体中剥离所有验收/证据内容（包括 `### Acceptance Criteria`、`#### Acceptance Criteria`、`### Success Criteria`、`AC:` 前缀列表项、证据收集清单、交付物证明项）→ 迁移至 `Task N-V` QA 块；若缺失则创建 `Task N-V` 作为独立节点。
17. **检查点覆盖**——要求显式 `CP0`/`CP1`/`CP2`/`CP3` 定义。检查点输出必须映射到关卡状态、固定章节和未解决阻塞项。关卡：`CHECKPOINT_MISSING`（节点缺失、无序或未映射到审计输出时失败）。
18. **索引状态同步**——对于 `plan-set`，索引必须有 Wave/Phase 复选框作为摘要；任务真实状态在阶段文件中。关卡：`INDEX_STATE_SYNC_MISSING`（无复选框、重复任务状态或缺少完成规则时失败）。修复：添加复选框，链接阶段，移除重复任务状态，定义 Phase 完成为所有可执行任务 + 配对验证节点完成，定义 Wave 完成为所有实现任务 + 配对 `Task N-V` 节点完成，若底层任务重新开启则重置受影响的复选框。
19. **子计划预检验证**——对于 `plan-set`，每个阶段文件必须以预检验证开始，在实现前检查上游阻塞项/契约。关卡：`SUBPLAN_PREFLIGHT_MISSING`（缺失时失败）。
20. **任务路由层级审计**——两层模型：贵价层（`deep`、`ultrabrain`、`visual-engineering`、`artistry`）仅用于专业能力；标准层（`unspecified-high`、`unspecified-low`、`quick`、`writing`）作为默认。分解完整性：若任务可进一步拆分为更小独立单元 → `TASK_UNDER_DECOMPOSED`（硬失败）。贵价层用于常规任务 → `ROUTING_OVERKILL`（硬失败）。复杂任务路由到 `quick`/`unspecified-low` → `ROUTING_UNDERKILL`（软警告）。修复：将过度配置降级至标准层，若范围超出标准层容量则分解。每个任务应声明 `category`/`subagent_type`；延迟需要 `executor_judgment`/`routing_by_executor` + 一行理由。贵价任务应包含 `why_not_lower_cost`。

## 修复顺序

1. 执行 skill 头部、执行者注解、路由枚举
2. 用户摘要（`## User-Facing Summary`、`Development Core`、`User Requirements`）
3. 防漂移顶部章节（`## User Requirement Digest`、`## Intent Anchor`）
4. 规范契约漂移（`interface_prefix`、`versioning_scheme`、`evidence_root`、范围）
5. 检查点映射（`CP0`/`CP1`/`CP2`/`CP3`）和输出模式
6. 统一任务图（ID + 依赖）
7. 展平嵌套可执行工作
8. 计划规模审计和分解决策
9. 验证闭合（`Task N`/`Task N-V`）；从 `Task N` 剥离验收标准 → 迁移至 `Task N-V` QA 块
10. Plan-Set 索引状态模型（Wave/Phase 复选框 + 完成同步）；在创建 `Task N-V` 或节点重新开启后重新计算
11. 子计划预检验证阶段（仅 plan-set）
12. QA 可执行性和验证范围隔离
13. 检查点循环至闭合（`CP1`→`CP2`→`CP3`）和硬关卡重评估
14. 任务路由层级审计和过度配置任务的分解

## 输出要求

产出：

- `Verdict`：`PASS` 或 `REJECT`
- `Gate Summary`：按关卡码统计的失败硬关卡数
- `Hard Gates`：关卡码 + 失败章节列表
- `Warnings`：非阻塞质量问题
- `Fixed Sections`：已修改的确切章节
- `Needs Decision`：需要人工产品/契约决策的条目
- `Checkpoint Report`：CP0/CP1/CP2/CP3 状态、循环迭代次数、未解决阻塞项
- `User-Facing Summary`：确认 `Development Core` 和 `User Requirements` 在顶部附近以用户可读语言存在
- `Requirement Digest`：确认 `## User Requirement Digest` 保留用户的自然语言需求无漂移
- `Intent Anchor`：确认 `## Intent Anchor` 一致地捕获 `Why`/`What`/`Non-Goals`/`Must Not Drift`
- `Validation Scope`：确认验收/证据检查已隔离到验证任务/检查点
- `Plan Size`：计算的类别、声明的类别和分解判定
- `Index State`：对于 `plan-set`，确认 Wave/Phase 复选框存在、完成/重置标准已定义、勾选状态与阶段文件真实状态匹配

任何 `BLOCKED_NEEDS_DECISION` 条目仍开放 → 判定必须为 `REJECT`。

## 硬关卡 vs 软警告

### 硬关卡（必须为零才能 PASS）

`ID_GRAPH_MISMATCH` · `ROUTING_SCHEMA_INVALID` · `CONTRACT_DRIFT` · `QA_NOT_EXECUTABLE` · `VERIFY_CLOSURE_MISSING` · `STACK_MISMATCH_BLOCKING` · `NESTED_EXECUTABLES_FOUND` · `PLAN_SIZE_AUDIT_MISSING` · `PLAN_SET_REQUIRED` · `PARALLEL_DECLARATION_MISSING` · `CHECKPOINT_MISSING` · `VALIDATION_SCOPE_LEAK` · `USER_SUMMARY_MISSING` · `ANTI_DRIFT_TOP_SECTION_MISSING` · `INDEX_STATE_SYNC_MISSING` · `SUBPLAN_PREFLIGHT_MISSING` · `ROUTING_OVERKILL` · `TASK_UNDER_DECOMPOSED`

### 软警告

`ROUTING_HEURISTIC_WEAK` · `TASK_EXECUTOR_ANNOTATION_WEAK` · `THRESHOLD_UNJUSTIFIED` · `NOISY_VERIFICATION` · `ROUTING_UNDERKILL`

## 提级流程

1. 自动修复确定性文本问题（ID 重映射、显式依赖边、头部枚举修正、契约对齐）。
2. 高影响的模糊产品决策 → 问 1-3 个定向问题；若仍不确定 → `BLOCKED_NEEDS_DECISION`。示例：选择 `/api/` vs `/api/v1/`、是否将某功能纳入或排除出验证范围、用户需求和意图锚点无法一致映射。
3. 绝不猜测业务意图来「强制通过」。

## 与 Atlas/Prometheus 集成

- 权威性结构修复的落地路径，用于权威性计划编辑。在执行前和审查驱动的缺陷发现后使用。
- 定义结构有效、修复完成的计划应是什么样；不负责运行时执行顺序、证据纪律或提交时机。
- Atlas 将此作为规范性修复规格。Prometheus 提供紧凑的路由意图；本 skill 展开并执行具体修复关卡。
- `metis` 可能暴露遗漏，`oracle` 可能产出修订简报；权威性结构修复通过本 skill 落地，而非执行期间的行内修补。
- 输出在当前审查消息中行内发出；不需要单独的产物文件。

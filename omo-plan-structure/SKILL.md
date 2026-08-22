---
name: omo-plan-structure
description: 当当前代理承担 Prometheus（编写或修订计划）或 Momus（审查计划版本）角色，即将开始规划工作或审查任何计划版本前必须加载；只解释规则、问答，不产出或核对具体计划时不加载。
---

# OMO 计划结构标准

## 概述

本 skill 是 OMO 计划文件结构的**单一标准**：计划正文的区块构成、各区块必需内容、结构约束与计划/账本分离体制均以本文件为准。编写方（Prometheus）与审查方（Momus）共用本标准，任何一方不得另行复制或改写结构定义；结构类不一致以本文件裁决。生成方法与审查裁决规则由各自 prompt 承载，不在此复制。

## 反例（不应触发）

| 输入 | 原因 |
|---|---|
| "解释一下计划结构规则" | 不产出或核对具体计划 |
| 讨论需求、未开始写计划 | 无结构产出对象 |

## 正文区块

计划正文**只含以下五个静态区块**，均以二级标题组织并保持结构可机械判定：

1. `需求与目标`
2. `Workspaces`
3. `并发矩阵`
4. `Task 契约`
5. `检查点与集成`

- 静态区块置顶，保持前缀稳定以命中 prompt caching；基线预验证据以单行记入「检查点与集成」，不设专用模板区块。
- 正文承载当前生效投影：计划与契约修订原地更新正文，全部历史、裁决依据与修订摘要以 `plan_revision` 事件记入账本，正文严格只含五区块、不保留历史段。
- `需求与目标` 节开篇必须存在：节首附 3-5 行用户可读摘要（做什么、为什么、用户可见结果，非技术语言），需求逐条附可溯源标注并区分 **core**（不达成则交付无意义，二元验收）与 **preference**（期望方向，允许执行期降级）；溯源标记与判定细则由 Prometheus 规则定义。

## Workspaces 区块

- 含仓库写入的计划必须定义 `workspaces`，标注 `vcs: git | none` 和 `mode: current | worktree`，每个写入 task 引用唯一 `workspace_lane`。
- `vcs: git` 时必须标明**主分支**（项目默认分支，如 `main`）及**计划文件与账本在主分支下的存放路径**（如 `docs/plans/<plan-name>.md`、`docs/plans/<plan-name>.ledger.md`）；所有 worktree lane 自该主分支创建，计划与账本的权威版本只保留在主工作区（主分支检出）的该路径下，lane worktree 内不得另建计划或账本副本。`vcs: none` 时改标计划与账本所在目录的绝对路径。
- `mode: current` **必须记录 `authorization_source`**，指向用户对使用当前工作区的明确授权；普通计划批准、工作区看似干净或规划者判断**均不算授权**，且保留现有分支。
- 新建 worktree 命名：单 lane 主 workspace 或多 lane integration workspace 使用 `<plan-name>--main` 与分支 `work/<plan-name>/main`；实施 lane 使用 `<plan-name>--<task-key>` 与分支 `work/<plan-name>/<task-key>`。
- 存在多个写入 lane 时，必须增加唯一 integration task/workspace，依赖各 lane 的已验证产物，明确允许的汇合顺序，并只在集成树上运行最终验收与 Final Wave。
- 每个 workspace 的首个 task 验证并在必要时按计划身份创建环境。worktree 天然不含被 gitignore 的 env/本地配置文件：凡计划含**启动服务进行手动视觉巡查或人工运行时验证**的 task，必须写明从主工作区复制项目相应 env 文件到该 workspace（逐个列出文件名、源路径与目标路径），复制动作列入该 task 的 `环境 preflight`；计划只写路径不写机密值。

## 并发矩阵区块

- 表格逐 task 列出 cohort 归属、硬前驱、互斥写入与可变资源、workspace lane 与 route。
- cohort 是并行归属而非物理派发批次：实际分批由 Atlas 按并发预算执行，分批不改变归属。
- 预算口径：运行中写入 worker 与未验收积压之和**默认 ≤ 3**，**隔离充分时可至 4**；矩阵可声明 `concurrency_budget: N`，声明时以计划值为准（预算体制的**唯一覆盖入口**，与 shared skills、atlas 三方一致）。
- 拓扑豁免：单 writer 单 lane（允许串行多个写入 task）可写 `cohorts: none` 代替表格。

矩阵结构约束：

- 每个 Task 契约中的 task **必须在矩阵中恰好出现一次**；
- 硬前驱**必须可解析到已知 task**；
- 矩阵含依赖**必须无环**；
- 缺失、漏项或不可解析时**结构无效**，审查按官方 Executability 类别阻断；
- wave 节与全局矩阵必须一致（task 集合、硬前驱、cohort 归属）。

## Task 契约区块

每个实施 task 必须写明：

- `step_type`：`test-freeze` | `impl` | `test-supplement` | `integration`——测试先行三段组织的步骤类型；非测试先行任务为 `impl`。
- `目的`：一行内聚意图——本 task 交付什么可观察结果、直接服务哪个下游（消费者 task 或用户可见行为），用户可读语言，不用实现术语堆叠。
- `硬前驱` 与 `仅集成关联`
- `owner`
- 验收契约 `acceptance_contract`（初始基线 `contract_revision: 0`）：
  - 每条含稳定 `ID`、二元条件、证据取得方式与证据作用域文件清单；稳定 `ID` 从不复用，语义替换以 `supersedes` 关系表达（新条目 `supersedes` 旧条目，旧条目不原地改写）；
  - 计划批准后计算 `checklist_hash`；
  - 执行期修订一律 append-only，经执行侧分级裁决后以账本 `plan_revision` 事件生效；
  - 新增条目用新 `ID`，既有条目 `ID` 与 `hash` 不变。
- `允许输入`
- `唯一可写产物`
- `禁止范围`
- `环境 preflight`：运行时前置逐项列明步骤与来源路径——含服务启动、手动视觉巡查所需的 env 文件复制（源 → 目标）等
- `上下文胶囊`：相关文件清单、关键符号与行区间、规划期已验证结论、无需重复探索的范围，并记录生成时的代码 revision 锚（commit hash 或文件摘要），供 Atlas 注入前校验时效；落点已知且为单点修改的 task 豁免行区间与结论摘录，胶囊只写目标路径与符号名
- `验证命令`
- `可观察验收`
- `必要证据`
- `终止状态`：执行子代理返回 blocked 时必须附断点胶囊（已验证结论、已排除路径与卡点描述），供 Atlas 不重读旧会话即可重派
- `reviewer 安排`（条件字段）：命中独立 reviewer 条件时必填（何时命中的裁决规则由 Prometheus 规则承载）

## 检查点与集成区块

- 检查点是计划**唯一验收节点来源**，Atlas 的验收节奏直接挂靠，不另设重复节点。
- 检查点声明二选一：
  - 列出检查点：每个检查点给出纳入的 task 集合（应互斥，重复纳入须说明原因）、放行条件与验收命令；或
  - 写 `checkpoints: none` 并说明无需中间检查点的依赖与风险依据；仅显式 `none` 时由 Atlas 按依赖、背压与终态排水触发器验收。
- 检查点断言须标注证据强度（集成实测/切片单测拼装/类型检查），不得宣称高于证据强度；切片单测拼装的链不得宣称 E2E，需要 E2E 时显式加入范围。

## 计划与账本分离

- 动态状态（checkbox、验收回执、尝试次数、会话链与执行进度）**不写入计划文件**，记入配属的 append-only 执行账本 `<plan>.ledger.md`：账本只追加事件、不回改历史条目，恢复执行时重放尾部重建状态。
- 账本物理文件只保留在主目录（主分支下的存放路径），不复制到任何 lane worktree；全部 append 统一写入主目录账本。
- 正文与账本头部摘要不一致时执行侧 fail-closed，停止派发、验收与恢复。

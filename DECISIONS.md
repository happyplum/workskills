# Skills 仓决策记录

本文件记录持续影响本仓 skill 行为的用户决策与行为裁决，是本仓唯一的决策入口：修改任何 skill 行为前先核对其中的 `active` / `superseded` 状态，避免回退到已废弃方向。纯维护规范（写作标准、提交流程、结构约定）记录在 README，不记录于此。条目自包含，不依赖本仓之外的任何文件。

## 当前有效决策

### SK-001 计划结构单一标准（omo-plan-structure）

- 状态：`active`
- 决策：计划结构体系（区块构成、Task 字段、验收条目语法、矩阵结构约束、任务原子性契约、并行准入六条件、计划/账本分离）以 `omo-plan-structure` 为单一标准，编写方（Prometheus）与审查方（Momus）共用；任何一方不得另行复制或改写结构定义，结构类不一致以该 skill 裁决。本地计划不经上游 `ulw-plan` scaffold 生成，task 行保留上游 checkbox 语法与 `Recommended task executor category:` 字面前缀作为路由锚。
- 验收：结构 schema 只在 SKILL.md 一处定义；后续字段增改只改 skill 一处，消费方 prompt 不出现字段名漂移。
- 修订（2026-08-26，SK-015）：计划/账本分离的账本载体改为上游 `.omo/start-work/ledger.jsonl`。

### SK-002 计划分级与 Task 契约精简

- 状态：`active`
- 决策：
  - 计划分级：task 数 ≤3、单 lane、未命中高风险特征（公共接口或公共契约变化、架构或数据结构变化、不可逆动作、权限/安全边界——分级唯一判源）走轻量三节（摘要含 core 缺省与假设子行、节尾 Workspaces 一行 / 任务清单 / 终态验收含具名 gate 与 F1 行）；否则完整五区块。执行期超判据以一次 `topology_remap` 升格重排，既有验收条目 ID 与 `checklist_hash` 不变。
  - Task 字段 5 个：标题行（`[integration]` 前缀替代 step_type；`[test-freeze]` / `[test-supplement]` 已随 prompts 仓 D-017 改造移除）+ 路由行（上游 category 字面前缀保留、execution_mode 同行括注、`subagent_type=<name>` 二选一）+ 上下文胶囊 + 验收条目 + 写域；条件字段（环境 preflight / reviewer 安排 / 放弃-风险判据）另计。拓扑字段（硬前驱、仅集成关联、owner、lane）只写并发矩阵——矩阵是唯一拓扑事实源，账本 `owner` 取矩阵值。
  - 验收条目机械语法：`- <ID>：<二元条件> → 命令=<命令> 预期=<结果>` 一行一条，ID 惯例 `T<n>-A<m>`；高风险 task 同行尾追加 `scope=`；`checklist_hash` = 当前生效条目（未被 supersedes）按 ID 排序的原文行（去首尾空白）串接；CAS 三元组（artifact_revision / contract_revision / checklist_hash）与 append-only 修订不变。
  - 计划级通用约定（通用禁止、终止状态断点胶囊、package_manager、默认 load_skills）以 Task 契约区块引言一次承载；轻量计划由任务清单节首引言承载。
- 验收：固定字段合计 ≤5 行/task、验收每条 1 行，task 参考区间 12-20 行；胶囊密度不设上限（decision-complete 是北极星）。
- 修订（2026-08-26，SK-015）：`checklist_hash` 定义随 CAS 废除而移除；条目 `ID` 与 `supersedes`、append-only 语法不变。

### SK-003 经济路由与失败升档（omo-adaptive-execution）

- 状态：`active`
- 决策：
  - 最小化拆解立场：拆解以任务内聚为限、不为并行制造任务；相互独立的 task 用最低足够档位的 worker 并发执行，不追求代理数量（上游 sizing 规则与 Cognition「共享推理不拆」为依据）。
  - 原子性契约含 sizing 裁决：内聚单元超出 `quick` / `unspecified-low` 单次可执行尺寸时，优先沿独立 owner / failure family / 可独立验收边界继续拆小；共享同一推理、不可拆的直接路由高档（路由下限规则仍适用），不用低档硬试。
  - 升档协议：归因前置（排除缺上下文/依赖/环境误归因）；阶梯 `quick → unspecified-low → unspecified-high` 线性，之上按失败性质选 `deep`（陌生领域探索）或 `ultrabrain`（推理复杂度）；升档前复核不可拆、委托补 `WHY_NOT_LOWER_COST`、新会话注入断点胶囊续用原 `task_id`；每次升档计入补救预算（默认 2 次），顶档仍失败转 blocked / oracle / 用户。
  - worker 返回 `blocked` 必须附断点胶囊（已验证结论、已排除路径、卡点描述）。
- 验收：高价路由有 `WHY_NOT_LOWER_COST` 点名失败证据；升档重派有预算记录，无无限升档。

### SK-004 验收节点统一召回（执行节奏）

- 状态：`active`
- 决策：删除逐任务验收仪式——`omo-adaptive-execution` 滚动波次的 COLLECT/VERIFY 阶段为集中验收：预算内持续 fan-out 补位，验收集中在 wave 末、检查点、依赖解锁前、终态排水；预算口径（运行中写入 worker + 未验收产物，默认 3、隔离充分至 4、计划 `concurrency_budget` 唯一覆盖）为强制背压，达到上限先统一验收再派发；公共接口、持久化、安全、并发、迁移、不可逆等高风险边界完成即验收。
- 验收：滚动波次 COLLECT/VERIFY 表述与节点统一召回一致；预算上限仍为强制背压。
- 修订（2026-08-24，SK-007）：预算体制限定为计划路径；Sisyphus 日常路径的并发节奏由 overlay 蜂群滑动并发条款承接（SK-007），强制背压思想不变——运行中+未验收 ≤6 的滑动窗口即该路径的背压门。
- 修订（2026-08-26，SK-015/D-039）：「验收集中在四类节点」废止，回归上游逐 task 验证即勾选；预算背压与 Sisyphus 路径承接不变。

### SK-005 跨会话历史检索归入发现委托

- 状态：`active`
- 决策：父协调级不自行多轮翻扫既往会话（`session_search` / `session_list` / `session_read` 历史溯源）；跨会话检索默认派后台子代理执行并加载 `opencode-subagent-log-triage`（session API、SQLite 兜底、结构化报告格式），单证据目标、返回结论摘要与定位引用（session_id 与轮次）；父级仅允许对已知 `session_id` 的单次定向查证；连续两次会话检索无结论即改派或放弃该线索。触发证据：真实会话中父级 query 漂移连发 7+ 次会话检索，原始输出污染主上下文并带偏后续检索。
- 验收：发现委托表含会话溯源行；反例表含「父级多轮翻扫会话历史」行。

### SK-006 计划 Workspaces 声明（主分支路径与巡查 env 复制）

- 状态：`active`
- 决策：`vcs: git` 的计划必须在 workspaces 声明中标明主分支及计划文件、账本在主分支下的存放路径；worktree lane 自该主分支创建，计划与账本权威版本只保留在主工作区该路径，lane 内不建副本。含「启动服务进行手动视觉巡查或人工运行时验证」的 task，必须写明从主工作区复制项目相应 env 文件到目标 workspace（逐个列出文件名、源路径与目标路径），复制动作列入该 task 的 `环境 preflight`；计划只写路径不写机密值。
- 验收：git 计划的 workspaces 声明含主分支与存放路径；视觉巡查类 task 的 `环境 preflight` 含 env 复制条目且正文无机密值。

### SK-007 并发节奏双模式（overlay 蜂群例外）

- 状态：`active`
- 决策：`omo-adaptive-execution` 的波次制与并发预算（默认 3/4，`concurrency_budget` 唯一覆盖）为**计划路径**（Atlas/矩阵）节奏；例外条款**仅限 Sisyphus overlay（日常任务路径）**显式声明的蜂群滑动并发模式可覆盖节奏与数值上限（运行中 + 未验收 ≤6 滑动窗口：依赖就绪集单批爆发、完成即释放额度滑动补位、排水点统一验收）。不豁免项：写域互斥、命名依赖串行（后继读取前驱产物、同文件写入）、验收门（排水点统一验收 + 高风险边界完成即验）、Category 路由与升档协议、发现委托、质量门。SK-003 的最小化拆解与「共享推理不拆」边界不变；SK-004 的预算体制在 Sisyphus 路径由 overlay 蜂群条款承接。
- 验收：skill 例外条款含角色限定与不豁免清单；路径选择表与反例表「ready 即全部派发」行含蜂群例外限定；skill 内「唯一覆盖入口」表述带「计划路径」限定。

### SK-008 审查协议单一来源（omo-plan-review）

- 状态：`active`
- 决策：计划审查流程协议（单审/双审两阶段循环——先 Oracle 循环至 `OKAY` 再 Momus 循环至 `OKAY`、Momus 阶段修订不回送；reviewer 委托注入模板——Oracle 架构层大雷判据与 `handoff-to-momus`、Momus 机械维度穷举与三判定要求；温链收敛默认 1 轮最多 2 轮、`WHY_HIGH_REVIEW_COST` 成本门槛）由 `omo-plan-review` 单一承载，用户选送审时由 Prometheus 加载；`prometheus.md` 只保留三选项与加载指令，不复制协议（「派发方持有协议、判据随委托注入」原则）。审查判定附件格式（`tdd`/`split`/`route` 逐 task 一行、绑定计划版本、`review_verdict` 入账）与「路由档位判据」速览（quick/low/high/deep/ultrabrain/visual-engineering 适用边界——Prometheus 标注与 Momus 判定共用）定义于 `omo-plan-structure`；完整执行映射（`WHY_NOT_LOWER_COST`、升降档协议）仍归 `omo-adaptive-execution`。
- 验收：审查协议条款只在 `omo-plan-review` 一处；`prometheus.md` 无循环/注入/收敛条款复制；`omo-plan-structure` 含判定附件格式与路由档位判据两节。

### SK-009 Sisyphus 简单自改例外（路径选择表）

- 状态：`active`
- 决策（2026-08-25，prompts 仓 D-031）：`omo-adaptive-execution` 路径选择表「产品代码：单一机械实现或修复 → 恰好 1 个 quick worker；协调者只验收不写产品代码」加 Sisyphus overlay 例外标注——Sisyphus 简单改动自改 + 统一回归验收（少量修正自修、量大派修、上下文防污染，细则见其 overlay）；**Atlas 不适用例外**（计划路径仍纯编排）。蜂群与预算体制（SK-007）不变。
- 验收：路径选择表含例外与 Atlas 不适用标注；skill 其余条款无「Sisyphus 不写产品代码」表述。

### SK-010 委托契约对齐上游六段

- 状态：`active`
- 决策（2026-08-25，prompts 仓 D-032 同裁决）：`omo-adaptive-execution` 委托契约弃用本地六段（`[CONTEXT][GOAL][STOP WHEN][EVIDENCE][DOWNSTREAM][REQUEST]`），改用上游委托六段 `TASK / EXPECTED OUTCOME / REQUIRED TOOLS / MUST DO / MUST NOT DO / CONTEXT`——上游 Atlas 与 Sisyphus 均以 MUST 级强制该模板且上游不可改（用户裁决「上游优先」），双模板并存时本地对齐。本地原有语义折叠进对应段：`GOAL`→`TASK`，`STOP WHEN`+`EVIDENCE`→`EXPECTED OUTCOME`，`REQUEST`→`MUST DO`+`MUST NOT DO`，`DOWNSTREAM` 与目标语义锚→`CONTEXT`。worker 四态返回与断点胶囊不变。
- 验收：skill 与 prompts 引用处无旧六段名残留；原引用 `[EVIDENCE]` 的验收核对条款改为 `EXPECTED OUTCOME` 段。

### SK-011 Momus 委托模板补 handoff 承接

- 状态：`active`
- 决策（2026-08-25）：`omo-plan-review` Momus 委托注入模板补 handoff 承接条款——Oracle 阶段移交的 `handoff-to-momus` 显微发现必须出现在 Momus 核对清单，逐项核对：命中官方四类才升级 blocker，未命中在 verdict Summary 记录一句处置结论，不得静默丢弃。属 SK-008 迁移遗漏修复（D-016 验收「handoff 建议出现在 Momus 核对清单」补全）。
- 验收：omo-plan-review Momus 模板含 handoff 承接条款；handoff 产出端（Oracle 模板）与消费端（Momus 模板）闭环。

### SK-012 滚动波次验收节点补终态排水

- 状态：`active`
- 决策（2026-08-25）：`omo-adaptive-execution` 滚动波次 COLLECT/VERIFY 的验收节点枚举补「终态排水」，与 atlas.md 四节点口径（wave 末 / 检查点 / 依赖解锁前 / 终态排水）及 SK-004 对齐。
- 验收：skill 节点枚举为四节点，与 atlas.md 一致。
- 修订（2026-08-26，SK-015/D-039）：终态排水节点同步条款随节点体系废止而失效（终态排水保留为聚合强化点）。

### SK-013 计划工位对齐上游 .omo/plans

- 状态：`active`
- 决策（2026-08-25 用户裁决，prompts 仓 D-036 同裁决）：OMO 体系计划的存放路径约定由 `docs/plans/` 改为 `.omo/plans/`——上游 Momus 输入契约只认 `.omo/plans/*.md`（0 匹配即拒审），ulw-plan 计划工位与 `/start-work` 计划选择均基于该路径；本地对齐后送审管道与执行入口天然成立，不对上游契约做任何本地适配。`docs/plans/` 等其他路径为非 OMO 体系计划，不经本体系送审与执行。存量计划按其 workspaces 已声明路径继续生效，不强制迁移。
- 验收：`omo-plan-structure` workspaces 示例路径为 `.omo/plans/`；两仓活动文件无 `docs/plans` 新引用。

### SK-014 Oracle 审查注入升级为架构师评估

- 状态：`active`
- 决策（2026-08-25 用户裁决，prompts 仓 D-038 同裁决）：`omo-plan-review` Oracle 委托注入模板由「只阻断架构层大雷」升级为架构师评估——以架构师视角做架构分析、技术细节风险与技术盲点搜索，产出架构完善建议；`[REJECT]` 仍只限架构层大雷；非阻断产出双通道（架构完善建议与盲点清单随 verdict 交修订方，可机械核对的显微发现走 `handoff-to-momus` 移交 Momus）。审查意图随委托写明，Oracle 角色 prompt 保持架构师纯职（D-038 单职原则）。
- 验收：注入模板含架构师评估意图与非阻断双通道；Oracle 角色 prompt 无审查模式语句。

### SK-015 执行状态回归上游（ledger.jsonl 与逐 task 完成契约）

- 状态：`active`
- 决策（2026-08-26 用户裁决，prompts 仓 D-039 同裁决）：`omo-plan-structure` 账本载体改为上游 `.omo/start-work/ledger.jsonl`（计划/账本分离原则不变，本地事件同载体）；`checklist_hash` 定义随 CAS 废除而移除（验收条目 `ID` 与 `supersedes`、append-only 机械语法保留）；`omo-adaptive-execution` 滚动波次 COLLECT/VERIFY 改为「每个 task 完成即验证并勾选，检查点、集成与终态排水为聚合强化点」。受修订：SK-001（账本载体）、SK-002（checklist_hash）、SK-004（节点召回）、SK-012（节点同步条款失效）。
- 验收：两 skill 无 `<plan>.ledger.md` / `checklist_hash` 残留；滚动波次与 atlas.md 验收节奏一致。

### SK-016 账本路径随上游改名（.omo/ulw-execute/ledger.jsonl）

- 状态：`active`
- 决策（2026-08-26，上游 5.0.0-beta.24，prompts 仓 D-040 同裁决）：上游 start-work skill 更名 `ulw-execute` 并将证据账本路径改为 `.omo/ulw-execute/ledger.jsonl`；`omo-plan-structure` 的 workspaces 示例与「计划与账本分离」节路径同步。其余不变（`.omo/plans/` 计划工位、boulder、事件词表、`/ulw-execute` 计划选择语义）。
- 验收：skill 无 `.omo/start-work` 残留。

### SK-017 visual-engineering 边界收紧（按交付物性质判定）

- 状态：`active`
- 决策（2026-08-31，prompts 仓 D-042 同裁决，skills 29605b4）：`omo-adaptive-execution` Category 选择表 `visual-engineering` 行「不应使用」列由「非视觉实现」收紧为「非视觉实现；触碰 UI 文件或带 UI/manual QA 验收的实现任务同样不属此类——按交付物性质判定，不按触碰文件面或验收手段」。背景：chat-unify 计划执行中 Atlas 把触碰 UI 文件的实现任务（计划推荐 unspecified-high）误判为 visual-engineering，导致该分类模型池首位（kimi k3-256k）被反复命中且派发中断率偏高。
- 验收：Category 表 visual-engineering 行含交付物性质判定边界；边界细则不复制到其他仓 prompt（单一来源，atlas.md 只留引用与执行纪律）。

## 已废弃决策

（暂无）

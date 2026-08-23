# Skills 仓决策记录

本文件记录持续影响本仓 skill 行为的用户决策与行为裁决，是本仓唯一的决策入口：修改任何 skill 行为前先核对其中的 `active` / `superseded` 状态，避免回退到已废弃方向。纯维护规范（写作标准、提交流程、结构约定）记录在 README，不记录于此。条目自包含，不依赖本仓之外的任何文件。

## 当前有效决策

### SK-001 计划结构单一标准（omo-plan-structure）

- 状态：`active`
- 决策：计划结构体系（区块构成、Task 字段、验收条目语法、矩阵结构约束、任务原子性契约、并行准入六条件、计划/账本分离）以 `omo-plan-structure` 为单一标准，编写方（Prometheus）与审查方（Momus）共用；任何一方不得另行复制或改写结构定义，结构类不一致以该 skill 裁决。本地计划不经上游 `ulw-plan` scaffold 生成，task 行保留上游 checkbox 语法与 `Recommended task executor category:` 字面前缀作为路由锚。
- 验收：结构 schema 只在 SKILL.md 一处定义；后续字段增改只改 skill 一处，消费方 prompt 不出现字段名漂移。

### SK-002 计划分级与 Task 契约精简

- 状态：`active`
- 决策：
  - 计划分级：task 数 ≤3、单 lane、未命中高风险特征（公共接口或公共契约变化、架构或数据结构变化、不可逆动作、权限/安全边界——分级唯一判源）走轻量三节（摘要含 core 缺省与假设子行、节尾 Workspaces 一行 / 任务清单 / 终态验收含具名 gate 与 F1 行）；否则完整五区块。执行期超判据以一次 `topology_remap` 升格重排，既有验收条目 ID 与 `checklist_hash` 不变。
  - Task 字段 5 个：标题行（`[test-freeze]` / `[test-supplement]` / `[integration]` 前缀替代 step_type）+ 路由行（上游 category 字面前缀保留、execution_mode 同行括注、`subagent_type=<name>` 二选一）+ 上下文胶囊 + 验收条目 + 写域；条件字段（环境 preflight / reviewer 安排 / 放弃-风险判据）另计。拓扑字段（硬前驱、仅集成关联、owner、lane）只写并发矩阵——矩阵是唯一拓扑事实源，账本 `owner` 取矩阵值。
  - 验收条目机械语法：`- <ID>：<二元条件> → 命令=<命令> 预期=<结果>` 一行一条，ID 惯例 `T<n>-A<m>`；高风险 task 同行尾追加 `scope=`；`checklist_hash` = 当前生效条目（未被 supersedes）按 ID 排序的原文行（去首尾空白）串接；CAS 三元组（artifact_revision / contract_revision / checklist_hash）与 append-only 修订不变。
  - 计划级通用约定（通用禁止、终止状态断点胶囊、package_manager、默认 load_skills）以 Task 契约区块引言一次承载；轻量计划由任务清单节首引言承载。
- 验收：固定字段合计 ≤5 行/task、验收每条 1 行，task 参考区间 12-20 行；胶囊密度不设上限（decision-complete 是北极星）。

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

### SK-005 跨会话历史检索归入发现委托

- 状态：`active`
- 决策：父协调级不自行多轮翻扫既往会话（`session_search` / `session_list` / `session_read` 历史溯源）；跨会话检索默认派后台子代理执行并加载 `opencode-subagent-log-triage`（session API、SQLite 兜底、结构化报告格式），单证据目标、返回结论摘要与定位引用（session_id 与轮次）；父级仅允许对已知 `session_id` 的单次定向查证；连续两次会话检索无结论即改派或放弃该线索。触发证据：真实会话中父级 query 漂移连发 7+ 次会话检索，原始输出污染主上下文并带偏后续检索。
- 验收：发现委托表含会话溯源行；反例表含「父级多轮翻扫会话历史」行。

### SK-006 计划 Workspaces 声明（主分支路径与巡查 env 复制）

- 状态：`active`
- 决策：`vcs: git` 的计划必须在 workspaces 声明中标明主分支及计划文件、账本在主分支下的存放路径；worktree lane 自该主分支创建，计划与账本权威版本只保留在主工作区该路径，lane 内不建副本。含「启动服务进行手动视觉巡查或人工运行时验证」的 task，必须写明从主工作区复制项目相应 env 文件到目标 workspace（逐个列出文件名、源路径与目标路径），复制动作列入该 task 的 `环境 preflight`；计划只写路径不写机密值。
- 验收：git 计划的 workspaces 声明含主分支与存放路径；视觉巡查类 task 的 `环境 preflight` 含 env 复制条目且正文无机密值。

## 已废弃决策

（暂无）

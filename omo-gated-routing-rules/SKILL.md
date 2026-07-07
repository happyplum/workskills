---
name: omo-gated-routing-rules
description: 会话开始时必须加载。提供直接操作与 task() 委托的路由决策、经济优先 category/subagent 选择、贵价层提级理由和审查门控规范，在整个会话期间持续生效。
---

# OMO 路由门控规则

## 加载条件

会话开始时必须加载，在整个会话期间持续生效。本 skill 在需要做直接工具与 `task()` 委托选择时、子代理选择或审查门控会影响结果时提供决策规则。

## 核心目的

选择正确且经济的执行路径：精确的局部工作使用直接工具；需要发现、研究、实现分工或审查时使用委托；委托时选择最低可行成本层级；委托产出使用审查验证。

## 强制规则

1. 执行前必须先决定直接操作还是委托执行。
2. 每次 `task()` 调用只委托一个原子任务，除非任务确实不可分割；有依赖关系的操作必须等待完成后再执行。
3. 当可用的子代理存在时，仓库内发现使用 `@explore`，文档/OSS 研究使用 `@librarian`。
4. 委托实现任务时先选最低可行成本层级；直接工具足够时不委托，`quick`/`unspecified-low` 足够时不提级；贵价/高成本路由必须携带 `WHY_NOT_LOWER_COST` 或等价证据，且提级不能替代拆分。
5. 若 imported / copied plan 带入上游 runtime 名称、额外 category 或弱路由形状，先规范化到本地 authoring subset，再进入执行。
6. 涉及代码变更或决策的委托任务，必须对产出进行审查验证；优先用 `metis` 进行完成状态缺口检查。若 Metis 发现计划层面缺口，再用 `oracle` 深化分析并生成结构化计划修订指引。
7. 当用户要求继续、恢复或追问已有 `task()` 委托/子代理会话（如"继续""接着做""继续对话 xxx""continue""fix that"），必须优先通过 `task(task_id="ses_...")` 恢复原会话，不得为同一目标新开任务；若路由能力不可用，回退到直接工具和官方文档/context7/网络搜索，不得捏造能力或重复已委托的探索。

## 经济路由参考

**Category 成本顺序：** 直接工具 → `quick` → `unspecified-low` → `unspecified-high` → `deep` → `ultrabrain`。领域 category（`visual-engineering`、`artistry`、`writing`）按任务性质覆盖成本层级，但仍需要避免无证据提级。

| 任务形态 | 默认路径 |
|---|---|
| 已知文件、单步、无需发现 | 直接工具 |
| 仓库内搜索/模式发现 | `subagent_type="explore"`，后台 |
| 外部文档/示例/API 正确性 | `subagent_type="librarian"`，后台 |
| 模糊请求、完成状态/遗漏检查 | `metis` |
| 架构权衡、调试、Metis 后深度分析 | `oracle` |
| 显式计划审查 | `momus` |
| 有界、模式已知、低风险实现 | `category="quick"` |
| 多文件常规实现 | `category="unspecified-low"` |
| 范围较大且有中等不确定性 | `category="unspecified-high"` |
| 广泛不确定性和迭代发现循环 | `category="deep"` + 理由 |
| 硬推理、算法、复杂状态机 | `category="ultrabrain"` + 理由 |
| UI/UX/样式或截图验证 | `category="visual-engineering"` + 理由 |
| 文档/文案 | `category="writing"` |

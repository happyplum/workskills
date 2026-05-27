# oh-my-opencode 技能集

oh-my-opencode 多智能体系统的自定义技能集，覆盖路由调度、计划执行、外部协作与存储维护。

## 安装

将技能目录放置于 oh-my-opencode 的技能配置路径下（如 `~/.config/opencode/skills/`），重启会话后自动加载。

与手动治理命令对应的命令目录现已迁移为独立的 `commands/` Git 子仓库；为避免 `commands/README.md` 被命令加载器误识别，命令目录说明与命令入口文档请维护在上层同级 `../commands/docs/README.md`，不要继续把 command catalog 作为本 README 的主事实来源。

## 技能列表

### 路由与编排

路由调度与技能使用规范——决定「何时委托」和「如何选择」。

| 技能 | 说明 |
|------|------|
| [omo-gated-routing-rules](omo-gated-routing-rules/) | 工作路由决策——何时使用直接工具或 `task()` 委托，包含审查与避免重复的规则 |
| [omo-subagent-type](omo-subagent-type/) | `task()` 调用配置——子代理类型选择、category 选择、`load_skills` 与 `run_in_background`。**约束：`subagent_type` 与 `category` 必须二选一（XOR），不可同时传入；高价 category（如 `deep` / `ultrabrain` / `visual-engineering` / `artistry`）需带 `WHY_NOT_LOWER_COST` 证据。上游 OMO 平台存在 `sisyphus-junior` 等 runtime executor，但本仓库 authoring surface 不直接暴露它；若 imported plan 带入上游术语，先规范化到本地治理子集** |
| [superpowers-gated-rules](superpowers-gated-rules/) | 技能优先规范——对话开始及任何实现工作前，强制检查可用技能。将「这很简单」/「我已经知道」视为警告信号；Atlas/计划执行路径下还要求先闭合 `omo-subagent-type → subagent-driven-development → atlas-execution-constraints` 预加载链 |

### 计划与执行

计划生命周期——覆盖执行阶段协调。计划修复已迁至 `/repair-plan` command。

| 技能 | 说明 |
|------|------|
| [subagent-driven-development](subagent-driven-development/) | 子代理驱动共享治理——多步骤编码工作默认使用此工作流：先拆分为最小独立执行单元，标准层路由优先，贵价层需证据支持；若输入是 reviewed / imported plan，先确认其已被规范化为本地 execution-ready surface |
| [atlas-execution-constraints](atlas-execution-constraints/) | **执行时**确定性约束——面向大型任务可靠执行的验证排序、规范化、证据纪律与提级处理边界。核心执行链：`omo-subagent-type → subagent-driven-development → atlas-execution-constraints`；该链在任何 `task()` 委托或执行面展开前都必须先闭合 |

### 维护与存储

工具集成、记忆管理、工作区清理。

| 技能 | 说明 |
|------|------|
| [memory-restructuring](memory-restructuring/) | 持久化记忆存储的结构重组——拆分、精炼、重分类、去重。**范围边界：仅用于跨多条记忆的结构性重组，不适用于单条记忆编辑或一次性删除。手动触发：通常由用户或清理/治理流程显式点名调用** |
| [sisyphus-cleanup](sisyphus-cleanup/) | `.sisyphus` 工作区清理——盘点 → 验证状态 → 去重并保留持久知识 → 删除临时产物 → 证明清理结果。**仅限 `.sisyphus` 目录，不适用于通用文件系统清理。边界：清理后如需记忆重组，转交 `memory-restructuring`。手动触发：通常由用户或工作区清理流程显式点名调用** |

## 技能依赖关系

```
superpowers-gated-rules ──→ all skills (meta-guard, 对话开始时加载；Atlas/计划执行路径下先闭合 OMO/Atlas 预加载链)

omo-gated-routing-rules ──→ omo-subagent-type (互补配对：前者决定「是否委托」，后者决定「如何配置」)
        │
        └──→ 审查

subagent-driven-development ──→ omo-subagent-type / atlas-execution-constraints（共享 SDD 拆分、路由与提级规则来源）

atlas-execution-constraints
        │
        └──→ Atlas 核心执行链: omo-subagent-type → subagent-driven-development → atlas-execution-constraints（任何 task() 委托或执行面展开前先闭合）

sisyphus-cleanup ──→ memory-restructuring (清理时使用重组原则保留持久知识)
```

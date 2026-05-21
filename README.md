# oh-my-opencode Skills

oh-my-opencode 多智能体系统的自定义 Skill 集合，覆盖路由调度、计划执行、外部协作与存储维护。

## Installation

将 skill 目录放置于 oh-my-opencode 的 skills 配置路径下（如 `~/.config/opencode/skills/`），重启会话后自动加载。

## Skills

### Routing & Orchestration

路由调度与 Skill 使用规范——决定“何时委派”和“如何选择”。

| Skill | Description |
|-------|-------------|
| [omo-gated-routing-rules](omo-gated-routing-rules/) | 工作路由决策——何时使用直接工具或 `task()` 委派，包含审查与避免重复的规则 |
| [omo-subagent-type](omo-subagent-type/) | `task()` 调用配置——子智能体类型选择、category 选择、`load_skills` 与 `run_in_background`。**约束：`subagent_type` 与 `category` 必须二选一（XOR），不可同时传入；高价 category（如 `deep` / `ultrabrain` / `visual-engineering` / `artistry`）需带 `WHY_NOT_LOWER_COST` 证据** |
| [superpowers-gated-rules](superpowers-gated-rules/) | Skill-first 规范——对话开始及任何实现工作前，强制检查可用 Skill。将“这很简单”/“我已经知道”视为警告信号 |

### Planning & Execution

计划生命周期——覆盖执行前修复与执行阶段协调。

| Skill | Description |
|-------|-------------|
| [repairing-plans](repairing-plans/) | 计划验证与结构修复规范——结构性计划缺陷的修复方式，覆盖执行前检查以及审查后暴露的问题；包含任务 ID 图完整性、检查点审计（CP0-CP3）、路由 schema 有效性、验证闭环与任务粒度审计。结构无效时通过此 skill 修复 |
| [subagent-driven-development](subagent-driven-development/) | Subagent-Driven 共享治理——多步骤编码工作默认使用此工作流：先拆分为最小独立执行单元，标准层路由优先，贵价层需证据支持 |
| [atlas-execution-constraints](atlas-execution-constraints/) | **执行时**确定性约束——面向大型任务可靠执行的验证排序、规范化、证据规范与升级处理边界。核心执行链：`omo-subagent-type → subagent-driven-development → atlas-execution-constraints` |

### External Collaboration

外部模型交互——开展协作、审查与验证。

| Skill | Description |
|-------|-------------|
| [codex-gemini-collab-rules](codex-gemini-collab-rules/) | 外部模型**代码协作**——Codex/Gemini 会话管理、安全边界、仅返回 unified diff patch、禁止外部模型直接写文件 |
| [external-model-review](external-model-review/) | 外部模型**审查与验证**——将计划/代码发送至 Codex/Gemini/Claude 验证，强制 human-in-the-loop。触发词："外部审查"、"进行外部审查"、"计划外部审查" |

### Maintenance & Storage

工具集成、记忆管理、工作区清理。

| Skill | Description |
|-------|-------------|
| [serena-gated-rules](serena-gated-rules/) | Serena 符号级导航/编辑准入规则，以及项目变更后的 Serena 记忆卫生同步（固定顺序执行） |
| [memory-restructuring](memory-restructuring/) | 持久化记忆存储的结构重组——拆分、精炼、重分类、去重。**范围边界：仅用于跨多条记忆的结构性重组，不适用于单条记忆编辑或一次性删除** |
| [sisyphus-cleanup](sisyphus-cleanup/) | `.sisyphus` 工作区清理——盘点 → 验证状态 → 去重并保留持久知识 → 删除临时产物 → 证明清理结果。**仅限 `.sisyphus` 目录，不适用于通用文件系统清理。边界：清理后如需记忆重组，转交 `memory-restructuring`** |

## Skill Dependencies

```
superpowers-gated-rules ──→ all skills (meta-guard, 对话开始时加载)

omo-gated-routing-rules ──→ omo-subagent-type (互补配对：前者决定“是否委托”，后者决定“如何配置”)
        │
        └──→ 审查

subagent-driven-development ──→ omo-subagent-type / repairing-plans / atlas-execution-constraints（共享 SDD 拆分、路由与提级规则来源）

atlas-execution-constraints ──→ repairing-plans (边界：计划结构无效时停止执行，请求修复)
        │
        └──→ Atlas 核心执行链: omo-subagent-type → subagent-driven-development → atlas-execution-constraints

external-model-review ──→ codex-gemini-collab-rules (管道：审查请求的模型交互遵循协作规则)

sisyphus-cleanup ──→ memory-restructuring (清理时使用重组原则保留持久知识)

serena-gated-rules ──→ memory-restructuring (边界：Serena 处理单次编辑整理，重组处理存储级重构)
```

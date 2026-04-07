# oh-my-opencode Skills

oh-my-opencode 多智能体系统的自定义 Skill 集合，覆盖路由调度、计划执行、外部协作与存储维护。

## Installation

将 skill 目录放置于 oh-my-opencode 的 skills 配置路径下（如 `~/.config/opencode/skills/`），重启会话后自动加载。

## Skills

### Routing & Orchestration

路由调度与 Skill 纪律——决定"何时委派"与"如何选择"。

| Skill | Description |
|-------|-------------|
| [omo-gated-routing-rules](omo-gated-routing-rules/) | 工作路由决策——何时使用直接工具 vs `task()` 委派，含 `@metis → @momus` 质量门控循环与反重复规则 |
| [omo-subagent-type](omo-subagent-type/) | `task()` 调用配置——子智能体类型选择、category 选择、`load_skills` 与 `run_in_background`。**约束：`subagent_type` 与 `category` 必须二选一（XOR），不可同时传入** |
| [superpowers-gated-rules](superpowers-gated-rules/) | Skill-first 纪律——对话开始及任何实现操作前，强制检查可用 Skill。将"这很简单"/"我已经知道"视为红旗警告 |

### Planning & Execution

计划生命周期——执行前修复与执行时治理。

| Skill | Description |
|-------|-------------|
| [repairing-plans](repairing-plans/) | **执行前**计划验证与修复——任务 ID 图完整性、检查点审计（CP0-CP3）、路由 schema 有效性、验证闭环、任务粒度审计（premium category 保留）。结构无效时 Atlas 停止并请求此 skill 修复 |
| [atlas-execution-constraints](atlas-execution-constraints/) | **执行时**确定性约束——验证排序、规范化、证据纪律与升级边界。依赖预加载链：`writing-plans → omo-subagent-type → executing-plans → atlas` |

### External Collaboration

外部模型交互——实现协作与审查验证。

| Skill | Description |
|-------|-------------|
| [codex-gemini-collab-rules](codex-gemini-collab-rules/) | 外部模型**实现协作**——Codex/Gemini 会话管理、安全边界、仅返回 unified diff patch、禁止外部模型直接写文件 |
| [external-model-review](external-model-review/) | 外部模型**审查验证**——将计划/代码发送至 Codex/Gemini/Claude 验证，强制 human-in-the-loop。触发词："外部审查"、"进行外部审查"、"计划外部审查" |

### Maintenance & Storage

工具集成、记忆管理、工作区清理。

| Skill | Description |
|-------|-------------|
| [serena-gated-rules](serena-gated-rules/) | Serena 符号级导航/编辑准入规则，以及项目变更后的 Serena 记忆卫生同步（固定顺序执行） |
| [memory-restructuring](memory-restructuring/) | 持久化记忆存储的结构重组——拆分、精炼、重分类、去重。**范围边界：仅用于跨多条记忆的结构性重组，不适用于单条记忆编辑或一次性删除** |
| [sisyphus-cleanup](sisyphus-cleanup/) | `.sisyphus` 工作区清理——盘点 → 验证状态 → 去重持久知识 → 删除临时产物 → 证明清理结果。**仅限 `.sisyphus` 目录，不适用于通用文件系统清理** |

## Skill Dependencies

```
superpowers-gated-rules ──→ all skills (meta-guard, 对话开始时加载)

omo-gated-routing-rules ──→ omo-subagent-type (互补配对：前者决定"是否委派"，后者决定"如何配置")
        │
        └──→ @metis → @momus 质量门控循环

atlas-execution-constraints ──→ repairing-plans (边界：计划结构无效时停止执行，请求修复)
        │
        └──→ 依赖预加载链: writing-plans → omo-subagent-type → executing-plans → atlas

external-model-review ──→ codex-gemini-collab-rules (管道：审查请求的模型交互遵循协作规则)

sisyphus-cleanup ──→ memory-restructuring (清理时使用重组原则保留持久知识)

serena-gated-rules ──→ memory-restructuring (边界：Serena 处理逐次编辑卫生，重组处理存储级重构)
```

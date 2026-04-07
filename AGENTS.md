# PROJECT KNOWLEDGE BASE

**Generated:** 2026-04-07
**Commit:** f76a438
**Branch:** master

## OVERVIEW

oh-my-opencode multi-agent system 的自定义 Skill 仓库。每个 skill 是独立目录，包含 SKILL.md 定义文件。纯文档项目，无构建/测试/CI。

## STRUCTURE

```
skills/
├── README.md                        # 项目总览 + 4 分类索引 + 依赖关系图
├── omo-gated-routing-rules/         # Core: 路由决策
├── omo-subagent-type/               # Core: task() 配置 (has AGENTS.md)
├── superpowers-gated-rules/         # Core: skill-first 纪律
├── atlas-execution-constraints/     # Execution: 执行时约束
├── repairing-plans/                 # Execution: 执行前计划修复
├── codex-gemini-collab-rules/       # External: 模型协作规则
├── external-model-review/           # External: 外部审查桥接 (has AGENTS.md, evals/)
├── serena-gated-rules/              # Maintenance: Serena 集成
├── memory-restructuring/            # Maintenance: 记忆重组
└── sisyphus-cleanup/                # Maintenance: 工作区清理
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Skill 定义 | `<skill-name>/SKILL.md` | YAML frontmatter + markdown |
| 补充文件 | `external-model-review/{template,examples}.md`, `evals/evals.json` | 唯一含 supplementary files 的 skill |
| 子目录 AGENTS.md | `omo-subagent-type/`, `external-model-review/` | 已有详细约定文档 |
| 分类与依赖 | `README.md` | 4 分类 + ASCII 依赖图 |

## CONVENTIONS

### SKILL.md 结构（YAML frontmatter + markdown）
- Frontmatter 仅 `name` + `description` 两个字段
- `description` 第三人称，以 "Use when..." 开头，仅描述触发条件
- `name` 仅字母、数字、连字符
- Frontmatter 总长 ≤1024 字符

### 标准节标题
- `## Overview` / `## Load Conditions` / `## Mandatory Rules` / `## Counter-Examples`
- `## Minimal CSO Triggers`（含 Primary + Secondary keywords）

### 常见节标题变体
- `repairing-plans`: 无标准 frontmatter（使用 `***` 分隔），节标题含 `## Required Checks`, `## Checkpoint Model`
- `atlas-execution-constraints`: 含 `## Preload Chain`, `## Verification Ordering`

### 文件命名
- 目录: kebab-case
- 文件: kebab-case（SKILL.md, AGENTS.md, template.md, examples.md）

### 语言
- Skill 内容: 英文
- 触发词（部分 skill）: 中文（如 external-model-review 的 "外部审查"）
- 用户输出: 中文

## ANTI-PATTERNS

| Pattern | Why Bad |
|---------|---------|
| Description 写工作流 | Agent 会跳过完整 skill，直接按描述执行 |
| >7 条 Mandatory Rules | 认知过载，保持 ≤7 条 |
| "Verify via LLM" | 不可机械验证，每条规则需可验证标准 |
| ASCII 流程图 | 浪费 token，LLM 按序处理文本 |
| 同类多例 | 稀释质量，维护负担 |

## REVIEW PROCESS

修改 skill 后执行 `@metis → @momus` 质量门控循环：
1. `@metis`（Critic）: 检测隐藏问题、AI 盲点、过度工程
2. `@momus`（Validator）: 验证完整性、逻辑正确性、风格合规
3. 迭代至通过

## NOTES

- `repairing-plans` 是最大的 skill（426 行），包含检查点审计模型（CP0-CP3）和 18+ 硬门控
- `omo-subagent-type/AGENTS.md` 包含完整的 skill 写作规范，是新增 skill 的参考文档
- `external-model-review` 是唯一包含 evals（`evals/evals.json`）的 skill

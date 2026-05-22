# 项目知识库


## 概述

oh-my-opencode 多智能体系统的自定义 Skill 仓库。每个 skill 是独立目录，包含 SKILL.md 定义文件。纯文档项目，无构建/测试/CI。

## 结构

```
skills/
├── README.md                        # 项目总览 + 4 分类索引 + 依赖关系图
├── omo-gated-routing-rules/         # Core: 路由决策
├── omo-subagent-type/               # Core: task() 配置 (has AGENTS.md)
├── superpowers-gated-rules/         # Core: skill-first 规范
├── subagent-driven-development/     # Execution: SDD 共享治理
├── atlas-execution-constraints/     # Execution: 执行时约束
├── repairing-plans/                 # Execution: 计划验证与结构修复
├── codex-gemini-collab-rules/       # External: 模型协作规则
├── external-model-review/           # External: 外部审查桥接 (has AGENTS.md, evals/)
├── serena-gated-rules/              # Maintenance: Serena 集成
├── memory-restructuring/            # Maintenance: 记忆重组
└── sisyphus-cleanup/                # Maintenance: 工作区清理
```

## 查找位置

| 任务 | 位置 | 备注 |
|------|----------|-------|
| Skill 定义 | `<skill-name>/SKILL.md` | YAML frontmatter + markdown |
| 补充文件 | `external-model-review/{template,examples}.md`, `evals/evals.json` | 如需查看补充模板、示例和评测，优先从这里开始 |
| 子目录 AGENTS.md | `omo-subagent-type/`, `external-model-review/` | 另有详细约定文档 |
| 分类与依赖 | `README.md` | 4 分类 + ASCII 依赖图 |

## 约定

### SKILL.md 结构（YAML frontmatter + markdown）
- Frontmatter 仅 `name` + `description` 两个字段
- `description` 中文描述，以「当……时使用」格式，仅描述触发条件
- `name` 仅字母、数字、连字符
- Frontmatter 总长 ≤1024 字符

### 标准章节标题
- `## 概述` / `## 加载条件` / `## 强制规则` / `## 反例`
- `## 最小 CSO 触发词`（含主要 + 次要关键词）

### 常见章节标题变体
- `repairing-plans`: 无标准 frontmatter（使用 `***` 分隔），节标题含 `## 必需检查`、`## 检查点审计模型`
- `atlas-execution-constraints`: 含 `## 必需预加载链`、`## 验证与关卡顺序`
- `subagent-driven-development`: 含共享的拆分、路由、贵价层约束与提级边界规则

### 文件命名
- 目录: kebab-case
- 文件: kebab-case（SKILL.md, AGENTS.md, template.md, examples.md）

### 语言
- Skill 内容: 中文（章节标题、正文、表格内容均已中文化）
- 系统标识符: 英文（`name` 字段、代码块、命令、文件路径、技术术语）
- 触发词: 中文（如 external-model-review 的「外部审查」）
- 用户输出: 中文

## 反模式

| 反模式 | 为什么不好 |
|---------|---------|
| 在 Description 中展开工作流 | Agent 会跳过完整 skill，直接按描述执行 |
| >7 条强制规则 | 认知过载，保持 ≤7 条 |
| "Verify via LLM" | 不可简单验证，每条规则需可验证标准 |
| ASCII 流程图 | 浪费 token，LLM 按序处理文本 |
| 同类多例 | 稀释质量，维护负担 |

## 审查流程

修改 skill 后进行审查：
1. 检测隐藏问题、AI 盲点、过度工程
2. 迭代直到通过

## 备注

- `repairing-plans`（172行）和 `omo-subagent-type`（159行）是仓库里最大的两个 skill，分别包含检查点审计模型（CP0-CP3）和 task() 路由决策树
- `omo-subagent-type/AGENTS.md` 包含完整的 skill 写作规范，是新增 skill 的参考文档
- `external-model-review` 提供模板、示例与 `evals/evals.json`，是查看外部审查配套材料的首选入口
- `sisyphus-cleanup` 与 `memory-restructuring` 有明确边界：前者仅处理 `.sisyphus` 工作区临时产物，后者处理持久化记忆的结构性重组；清理时先 sisyphus-cleanup 再按需 memory-restructuring

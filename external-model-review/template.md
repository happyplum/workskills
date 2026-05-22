# 外部模型审查 - 混合输出模板

## 概述

本 skill 使用**混合输出**：聊天摘要（控制面）+ 文件包（数据面）。

**控制面（聊天）**：简洁的操作卡片，含文件路径、说明和包装提示词。
**数据面（文件）**：完整的审查包，含精炼内容，写入 `external-review-request.md`。

---

# 模板 1：聊天摘要（控制面）

当用户触发外部审查时输出到聊天：

```markdown
## 📤 外部审查就绪

**审查目标：**
[一句话描述需要审查的内容和原因]

**关注领域：**
- [关注领域 1]
- [关注领域 2]
- [关注领域 3]

**审查包：**
`[ABSOLUTE_PATH_TO_FILE]`

**操作说明：**
1. 打开上述文件（或复制其全部内容）
2. 粘贴到 Gemini、Codex 或 Claude
3. 将 JSON 响应粘贴回此处

**可选包装提示词：**
> Review the following markdown packet. Follow the "Required Output" section exactly. Analysis only. No implementation. No code patches.

---
```

---

# 模板 2：审查请求文件（数据面）

写入项目根目录的 `external-review-request.md`：

```markdown
# External Review Request

## Reviewer Rules
- Analysis only.
- No implementation.
- No code patches.
- No file edits.
- No invented facts.
- If context is incomplete, state assumptions clearly.
- Use repo-relative paths only.

---

## Review Objective
[One short paragraph describing what needs review and why.]

---

## Questions To Answer
1. [Primary review question]
2. [Secondary review question]
3. [Optional targeted question]

---

## Scope

### In Scope
- [System, module, plan, or file group]
- [Specific decision or risk area]
- [Specific behavior or constraint]

### Out of Scope
- [Anything the reviewer should ignore]
- [Implementation details not needed]
- [Unrelated future work]

---

## Repository Context
- **Repo/Project:** [name]
- **Relevant Area:** [subsystem or feature]
- **Current State:**
  - [Bullet 1]
  - [Bullet 2]
  - [Bullet 3]
- **Key Constraints:** [stack, product, security, performance, timeline]

---

## Material Manifest
| Type | Path | Why It Matters |
|------|------|----------------|
| Plan | `path/to/plan.md` | Primary implementation plan |
| Research | `path/to/research.md` | Background and trade-offs |
| Notes | `path/to/notes.md` | Investigation findings |
| Evidence | `path/to/evidence.txt` | Supporting proof |
| Code | `path/to/code.ts` | Relevant implementation |

---

## Plan Summary
[Summarize the plan in 5-15 bullets. Do NOT paste full document unless very small.]

- [Key point 1]
- [Key point 2]
- [Key point 3]

---

## Research and Background
[Summarize ONLY findings that materially affect review quality.]

---

## Evidence

### Key Findings
- [Fact] — Source: `path/to/source`
- [Fact] — Source: `path/to/source`

### Selected Excerpts
```text
[path: src/service.ts]
[Paste ONLY the excerpt needed for review - max 50 lines]
```

```text
[path: plan.md]
[Paste ONLY the critical section - max 30 lines]
```

---

## Known Risks or Open Questions
- [Known risk or uncertainty]
- [Open question]

---

## Review Priorities
- Prioritize correctness over completeness.
- Prioritize blockers over style issues.
- Prioritize concrete evidence over generic advice.
- Flag ambiguity when it changes the recommendation.

---

## Required Output

Return **exactly one** fenced `json` block and nothing else.

```json
{
  "reviewer": {
    "model": "string",
    "review_type": "architecture|security|performance|code_quality|plan",
    "confidence": "high|medium|low",
    "date": "YYYY-MM-DD"
  },
  "summary": {
    "verdict": "approve|approve_with_changes|needs_revision|block",
    "score": 0,
    "one_sentence_rationale": "string"
  },
  "issues": [
    {
      "id": "I1",
      "severity": "critical|major|minor",
      "title": "string",
      "path": "repo/relative/path.ext or N/A",
      "evidence": "string",
      "why_it_matters": "string",
      "recommended_change": "string"
    }
  ],
  "open_questions": [
    "string"
  ],
  "assumptions": [
    "string"
  ]
}
```

### Output Rules
- Output English only.
- Output exactly one fenced `json` block.
- Use repo-relative paths only.
- Use empty arrays when there are no items.
- Do not include code patches.
- Do not restate the full prompt.
- Do not add markdown outside the `json` block.
```

---

# 内容精炼启发式

构建审查包时，应用以下规则：

## 文件大小限制

| 内容类型 | 最大行数 | 超出时动作 |
|----------|----------|------------|
| 计划摘要 | 30 行 | 仅列表摘要 |
| 研究摘要 | 20 行 | 仅关键发现 |
| 每段代码摘录 | 50 行 | 裁剪至相关函数 |
| 每个证据块 | 30 行 | 摘要，展示关键片段 |

## 应包含的内容

**始终包含：**
- 架构决策及其理由
- 安全敏感的代码段
- 性能关键路径
- 错误处理逻辑
- 集成点

**绝不包含：**
- 样板代码
- 自动生成的文件
- 测试固件
- 完整配置文件（仅展示相关部分）
- 导入语句（除非与问题相关）

## 路径约定

| 上下文 | 路径格式 | 示例 |
|--------|----------|------|
| 文件内容（审查包） | 仓库相对路径 | `src/auth/service.ts` |
| 聊天摘要 | 绝对路径（Windows） | `C:\project\src\auth\service.ts` |

---

# 使用摘要

## 本地代理

1. **定位**所有相关文件
2. **精炼**内容（使用上述启发式规则）
3. **写入** `external-review-request.md`（使用模板 2）
4. **输出**聊天摘要（使用模板 1）
5. **等待**用户粘贴 JSON 响应

## 用户

1. 打开文件或复制其内容
2. 粘贴到外部模型（Gemini、Codex、Claude）
3. 复制 JSON 响应
4. 粘贴回本代理

## 外部模型

1. 审查所有材料
2. 不生成代码或修改文件
3. 仅返回一个 JSON 块
4. 包含信心分数和假设

# AGENTS.md - 外部模型审查 Skill

## 项目概述

这是一个 OpenCode skill 仓库，用于桥接本地代理与外部 AI 审查者（Codex、Gemini、Claude），实现计划验证、架构审查、安全审计和代码审计。

**核心原则**：外部审查者仅分析——永不执行。人工在环审批是强制性的。

## 仓库结构

```
external-model-review/
├── SKILL.md          # 主 skill 定义（YAML frontmatter + markdown）
├── template.md       # 混合输出模板（聊天摘要 + 文件包）
├── examples.md       # 真实使用示例
├── evals/
│   └── evals.json    # skill 验证测试用例
└── AGENTS.md         # 本文件
```

## 构建/测试命令

**无构建系统**——这是一个纯文档仓库。

### 验证

```bash
# 验证 JSON 语法
node -e "JSON.parse(require('fs').readFileSync('evals/evals.json'))"

# 检查 markdown 结构
# - SKILL.md 必须有含 `name` 和 `description` 的 YAML frontmatter
# - template.md 必须包含 "模板 1" 和 "模板 2" 章节
# - examples.md 必须有至少 2 个示例
```

### 运行评测

无自动化测试运行器。手动验证：
1. 从 `evals/evals.json` 读取每个测试用例
2. 针对 skill 行为模拟提示
3. 验证 `expected_output_contains` 字符串出现在输出中
4. 验证 `expected_not_contains` 字符串未出现在输出中

## 代码风格指南

### Markdown 文件

**标题：**
- 使用 `#` 作为文档标题（每文件一个）
- 使用 `##` 作为主要章节
- 使用 `###` 作为子章节
- 最多 3 级嵌套

**表格：**
- 始终包含标题行
- 使用 `|` 加空格：`| Column | Value |`
- 列对齐一致

**代码块：**
- 始终指定语言：```markdown、```json、```bash
- 使用围栏块（```）而非缩进代码

**列表：**
- 无序列表使用 `-`
- 有序列表使用 `1.`（而非 `1)`）
- 标记后单个空格

### JSON 文件

**结构：**
```json
{
  "test_cases": [
    {
      "name": "Descriptive Test Name",
      "prompt": "User prompt to test",
      "expected_output_contains": ["string1", "string2"],
      "expected_not_contains": ["bad_string"]
    }
  ]
}
```

**规则：**
- 2 空格缩进
- 无尾随逗号
- 键使用 snake_case
- 字符串值使用双引号

### SKILL.md 特定

**必需 Frontmatter：**
```yaml
---
name: skill-name
description: 含中文触发词的触发描述
---
```

**必需章节：**
1. `## 概述` - 目的和范围
2. `## 文件清单` - 相关文件表格
3. `## 核心模式` - 阶段 1 和阶段 2 工作流
4. `## 用户触发识别` - 详细说明
5. `## 常见错误` - 反模式表格

**中文触发词：**
- 保留中文触发词（如「外部审查」）
- 其余内容使用中文
- 例外：面向用户的示例可包含中文上下文

### template.md 特定

**模板结构：**
- `# 模板 1：聊天摘要` - 控制面输出
- `# 模板 2：审查请求文件` - 数据面输出
- `# 内容精炼启发式` - 大小限制和规则
- `# 使用摘要` - 针对各角色（代理、用户、外部模型）

**路径约定：**
| 上下文 | 格式 | 示例 |
|--------|------|------|
| 文件内容 | 仓库相对路径 | `src/auth/service.ts` |
| 聊天摘要 | 绝对路径（Windows） | `C:\project\src\auth\service.ts` |

## 命名约定

| 类型 | 约定 | 示例 |
|------|------|------|
| 文件名 | kebab-case | `external-model-review`、`evals.json` |
| 章节标题 | 中文标题 | `## 怀疑协议` |
| JSON 键 | snake_case | `expected_output_contains` |
| 任务前缀 | `[External]` | `[External-CRITICAL] 修复问题` |

## 错误处理

**在 Skill 定义中：**
- 每种「常见错误」必须提供「正确做法」
- 使用表格提高清晰度：`| 错误 | 失败原因 | 正确做法 |`

**在模板中：**
- 包含「红旗」章节用于验证
- 假设失败时提供回退说明

## 关键约束

1. **人工在环**：绝不自动应用外部建议
2. **怀疑协议**：应用前始终验证外部发现
3. **混合输出**：聊天摘要（简洁）+ 文件包（详细）
4. **JSON 响应**：外部模型必须返回严格 JSON 格式
5. **路径隐私**：文件中使用仓库相对路径，聊天中使用绝对路径

## 编辑本 Skill

修改 skill 文件时：

1. **SKILL.md 变更**：添加新文件时更新 `文件清单` 表格
2. **template.md 变更**：确保两个模板保持一致
3. **examples.md 变更**：包含完整的请求/响应周期
4. **evals.json 变更**：为新功能添加对应测试用例

### 验证清单

- [ ] JSON 语法有效（无尾随逗号）
- [ ] Markdown 渲染正确
- [ ] 所有 `@file` 引用存在
- [ ] 中文触发词保留
- [ ] 表格列数一致
- [ ] 代码块已指定语言

## 外部依赖

无——这是一个自包含的 skill 仓库。

## 相关 Skill

- `writing-plans` - 创建可审查的实现计划
- `executing-plans` - 执行已审查的计划
- `requesting-code-review` - 人工专家审查工作流

---
name: codex-gemini-collab-rules
description: 当计划通过 collaborating-with-codex 或 collaborating-with-gemini 将任务交接给外部模型时使用。
---

# Codex/Gemini 协作规则

## 加载条件

当计划调用 `collaborating-with-codex` 或 `collaborating-with-gemini` 进行外部模型协作时加载。

## 强制规则

1. 若返回了 `SESSION_ID`，记录并在后续显式决定是否继续多轮对话。
2. 禁止通过外部模型通道写入本地文件系统。
3. 要求外部模型对代码变更只返回**统一差异补丁（unified diff patch）**；分析任务只返回发现/建议。
4. 外部模型产出仅作原型；应用前必须按项目风格重构。
5. 禁止未经本地验证就直接应用子代理/外部模型的产出。
6. 未经具体本地验证证据，不得声称修复完成或审查就绪。
7. 交接前必须从提示词/补丁中剥离或拦截任何潜在的敏感信息。

## 失败处理

若所需的协作 skill/工具不可用，跳过本 skill，仅使用本地工具继续。

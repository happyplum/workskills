---
name: serena-gated-rules
description: 当项目编辑需要使用 Serena 符号级编辑能力，或持久化项目内容/计划变更后需要 Serena 记忆同步时使用。
---

# Serena 门控规则

## 加载条件

当精确的项目编辑应使用 Serena，或持久化项目变更需要 Serena 记忆同步时加载。

## 核心目的

使用 Serena 进行符号级编辑和持久化知识维护，而非通用搜索或临时任务日志。

## 强制规则

1. 深度项目编辑前先初始化 Serena 上下文。
2. 当 Serena 能精确执行变更时，优先使用 Serena 符号/导航/编辑工具而非大范围文本替换。
3. 持久化项目内容或计划变更后，执行记忆维护。
4. 只持久化可复用的项目知识；禁止存储临时任务对话。
5. 若存在书面计划或 TODO 列表，每个条目必须声明记忆影响：`update`、`delete`、`rename`、`write` 或 `none`。

## 记忆维护顺序

- 维护顺序：`list_memories` → `read_memory` → `edit_memory` → `rename_memory` → `write_memory` → `delete_memory`。
- 计划条目在其记忆影响执行或标记为 `none` 前不算完成。

## 失败处理

- 若 Serena 工具不可用，跳过本 skill，使用非 Serena 的回退工作流/工具。

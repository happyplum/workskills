---
name: vue-standards
description: 当用户要求按自包含的 Vue 3 + Element Plus 中后台工程习惯搭建、实现、评审或改造 Vue 项目，或将规范转成项目 AGENTS.md 时使用（不依赖其他规范 skill，以手动或显式加载为主）。
---

# Vue 3 中后台工程规范

## 概述

一套自包含的 **Vue 3（`<script setup>`）+ Element Plus + Pinia + Vue Router** 中后台工程规范，覆盖目录结构、请求管道、表格/表单/弹窗/图表封装以及构建工程化习惯。本 skill 独立完整，无需先加载 `dev-standards`。

> **使用边界**：在团队协同或非本人主导的项目中，仅当用户明确要求时才应用本规范，不主动强加或改造项目原有结构；项目自身的架构与治理规则优先。

## 按需阅读路径

| 使用场景 | 必读文件 |
|---|---|
| 编写任何 Vue 代码前 | 先读本文件（目录总览 + 十条核心习惯） |
| 建目录、落文件、命名、配置路由与菜单 | 读取 `references/structure.md` |
| 写接口封装、请求拦截、错误回退、列表页与会话管理 | 读取 `references/request-error.md` |
| 写表格、分页表格、表单、弹窗、布局与图表 | 读取 `references/table-form.md` |
| 配 Lint、Git Hooks、Mock、i18n、样式主题与构建 | 读取 `references/engineering.md` |

## 推荐目录结构

```text
src/
├── apis/                       # 按业务域薄封装接口（每端点一函数，无 service 中间层）
├── types/apis/                 # 跨页共享接口类型（与 apis/ 域文件对应）
├── libs/                       # HttpRequest、i18n 等基础设施实例
├── router/routes/index.ts      # path → 页面组件映射表（生产默认保持干净）
├── router/menu/menuList.ts     # 菜单配置表（与路由分职，可聚合多路由）
├── views/children/<feature>/   # 业务页面目录：index.ts 对外入口 + 私有组件共置
├── components/                 # 通用基础封装组件（零业务语义，可带统一前缀）
├── components/views/           # 跨页业务复用组件（带业务语义或接口调用）
├── components/Workbench/       # 仪表盘 / 工作台小组件专区（Widget）
├── layout/                     # MainLayout / TableLayout / FormLayout
├── stores/                     # Pinia：仅存 user / menu / history 级跨页会话态
├── hooks/  utils/              # 带生命周期的组合式逻辑 / 无状态纯工具函数
├── locales/                    # UI 文案与错误文案分目录 + 多语言
└── styles/                     # 单入口分层 SCSS + UI 组件库覆写层
```

## 十条核心习惯

1. **一页一目录一入口**：每个独立路由页面放在 `views/children/<feature>/`，通过该目录的 `index.ts` 对外暴露唯一入口；`apis/`、`stores/`、`utils/` 等按类型集中的目录不建聚合 barrel。
2. **事实集中、UI 共置**：API、跨页类型、全局会话、多语言文案按类型集中存放；页面私有组件、子视图和私有小资源跟着页面目录走。
3. **三通道显式通信**：组件通信只用 `props` 下发、`emits` 上抛和 `ref` 实例方法——不用 `provide/inject`、不用全局事件总线、不用 `defineModel`（多字段 `v-model` 手写 `computed` get/set 代理）。
4. **不做页面列表缓存**：不用 `keep-alive` 缓存业务列表页，宁可切回重查也不留脏数据。
5. **组件写法唯一**：业务组件统一使用 `<script setup>`，显式声明 `defineOptions({ name })`，模板中组件标签统一 `PascalCase`。
6. **一表单多模式**：新增、编辑、详情共用同一个表单组件，通过路由区分模式（项目内统一唯一一种判断入口）。
7. **表格薄封装**：基础表格封装只统一列声明与插槽按名扩展，不接管页面的 loading、空态、分页和请求逻辑。
8. **开发与生产严格隔离**：示例页、调试路由和调试菜单全部通过 `import.meta.env.DEV` 条件注入，生产配置出厂保持干净。
9. **错误码三级回退**：集中请求拦截统一执行「错误码表（i18n 键）→ 允许展示的原始消息 → 默认兜底文案」回退。
10. **保持提交与仓库卫生**：统一提交信息格式；构建产物、编辑器个人配置及项目约定忽略的锁文件不入库。

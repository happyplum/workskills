---
name: vue-standards
description: lzy 的 Vue 工程规范（自包含 canon，蒸馏自 vue-vite-cli 法典模板与 group-web 生产实态，不依赖通用版 skill）。当用户要求按其 Vue 工程习惯搭建、评审或改造 Vue 项目，把个人规范快速转成项目 AGENTS.md，或当用户要求复用 DMTable/TableLayout/请求层/表单协议等既有范式时使用。以手动/显式加载为主。
---

# lzy Vue 工程规范（canon 版）

## 这是什么

从三个证据源蒸馏：vue-cli（旧代模板）→ vue-vite-cli（新代法典模板，权威起点）→ group-web（生产实态）。自包含：不依赖通用规范 skill（外部权威链为 vue-vite-cli 模板 rules/，见下）。

## 权威起点

新 Vue 工程直接克隆 E:\lzy\myProject\cli\vue-vite-cli（模板 + rules/ 法典 + dev.vue 可运行规范）。本 skill 是该模板的规格书与扩展说明；模板 rules/ 与本 skill 冲突时以模板为准并回改本 skill。

## 边界声明

本 skill 是个人 Vue 规范的主版本。协同开发或非本人主导的项目中，仅在用户明确要求时应用本 skill，不主动施加或改造项目结构；项目自身治理与结构约定优先。

## 渐进加载地图

| 时机 | 读什么 |
|---|---|
| 写任何 Vue 代码前 | 本文件（目录速览 + 十条铁律） |
| 建目录 / 落文件 / 命名 / 路由菜单 | `references/structure.md` |
| 写接口层 / 错误处理 / 列表页 | `references/request-error.md` |
| 写表格 / 表单 / 弹窗 / 图表 | `references/table-form.md` |
| 配 lint / 提交 / mock / i18n / 样式 / 构建 | `references/engineering.md`（含已知漂移清单） |

## 目录速览（一页图）

```
src/
├── apis/                       # 按域薄包装（每端点一函数，无 service 层）
├── types/apis/                 # 接口类型集中（跟 apis 域走）
├── libs/                       # HttpRequest 等基础设施
├── router/routes/index.ts      # path → import 路由地图（生产表可出厂为空）
├── router/menu/menuList.ts     # 菜单表（与路由分职，可聚合多路由）
├── views/children/<feature>/   # 业务页：index.ts 门口 + 私有件共置
├── components/                 # DM* 通用能力件（零业务语义）
├── components/views/           # 跨页业务复用件（带接口业务）
├── components/Workbench/       # 仪表盘 widget 特区
├── layout/                     # MainLayout / TableLayout / FormLayout
├── stores/                     # 仅 user/menu/history 级会话态
├── hooks/  utils/              # 生命周期行为 / 无状态工具
├── locales/                    # UI 文案与错误文案分轨 + 多语言
└── styles/                     # 单入口分层 SCSS + element 覆写层
```

## 十条铁律

1. 每个 URL 一个独立页面文件，经 feature 目录 `index.ts` 门口暴露
2. 事实集中、UI 共置：apis/types/stores/locales 集中；页面私有件跟页面走
3. 通信只用 props/emits/ref——零 provide/inject、零事件总线、零 defineModel（手写 computed 代理）
4. 无 keep-alive——宁重查不脏缓存
5. script-setup 唯一 + defineOptions(name) 必填 + 模板 PascalCase
6. 一表单多模式：新增/编辑/详情共用组件，路由分模式
7. 表格封装薄：列配置声明 + slot 位置路由，不拥有 loading/分页数据
8. 提交 `[type]` 格式；lock/.vscode/dist 不入库
9. demo/dev 路由菜单全部 import.meta.env.DEV 圈禁，生产表出厂即空
10. 错误三级回退：codeMap(i18n) → 原始 msg → 兜底文案

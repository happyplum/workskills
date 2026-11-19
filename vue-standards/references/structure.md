# Vue 目录结构与路由菜单规范

## 核心分界规则

**跨页业务事实按类型集中**（`apis/`、`types/`、`stores/`、`locales/`、`hooks/`、`utils/`、`styles/`）；**页面 UI 按业务功能共置**（`views/children/<feature>/` 放置主页面、页面私有组件、私有图标与私有类型）。

**判断口诀**：删掉这层页面 UI 它还成立吗？成立 → 放类型集中区；跟着页面生死 → 放页面目录共置。

> 常见边界：跨页共享 API 类型集中在 `types/apis/`；组件私有图标跟组件目录走；若后端按服务代码生成，可在 `apis/` 下按服务建独立子目录（内含对应的生成类型）。

## 业务页面目录形态（`views/children/<feature>/`）

- `<Feature>.vue` 主页面 + `index.ts` 唯一对外入口（仅做 `export { default } from './<Feature>.vue'`，不写逻辑、不堆砌多行转发）。
- 同业务域的私有子组件、`xxxForm.vue`、`xxxDetail.vue`、`xxxTab.vue`、私有 `svg/` 和 `types.ts` 同目录共置。
- 路由懒加载统一指向入口目录：`() => import('@/views/children/<feature>')`；同一业务目录内的子页面可直接引用 `.vue` 文件。
- 语义化文件名后缀：`Form`（新增/编辑/详情表单）、`Detail`（详情页）、`Tab`（页签内容）。

## 公共组件三区划分

| 目录 | 存放内容 | 准入标准 |
|---|---|---|
| `components/` | 通用基础封装组件：对 Element Plus、ECharts 等第三方库的二次封装（表格、分页表格、树、图表、按钮等） | 剥掉业务文案与接口后依然成立，可直接复制到其他项目 |
| `components/views/` | 跨页业务复用组件：带产品业务语义或接口调用（如登录框、权限树、业务图片上传） | 至少被 2 个页面复用，且绑定产品语义 |
| `components/Workbench/` | 工作台 / 仪表盘小组件（Widget） | 专供首页/工作台拼装的独立卡片挂件 |

- **通用基础组件前缀信号**：项目可约定一个简短前缀（如 `BaseTable`、`AppTable` 等）专用于标识对第三方库二次封装的基础能力组件；**业务组件绝不使用该前缀**。
- **抽取时机**：页面私有组件默认留在页面目录，直到**第二个实际调用方出现**才上提到 `components/views/`（不因为「以后可能会复用」提前抽取）。但明显零业务的通用能力组件（如富文本、通用日期选择、通用下拉），即使当前只有一页使用，也要先判断是否应放入 `components/`。

## 类型集中目录职责

| 目录 | 职责 | 准入边界 |
|---|---|---|
| `apis/` | 每个接口端点导出一个薄包装函数 | 不放 loading、缓存或业务状态；不建聚合 `index.ts` |
| `types/apis/` | 跨页接口入参与返回类型 | 与 `apis/` 业务域文件一一对应 |
| `libs/` | `HttpRequest`、i18n 等全局基础设施实例 | 基础设施层，不含页面逻辑 |
| `stores/` | Pinia：`user`、`menu`、`history` 等会话态 | 仅存跨页导航与会话态；表单、筛选、弹窗态一律留页内 |
| `hooks/` | 带 Vue 生命周期或监听清理逻辑的组合式函数 | 复用 ≥2 处或含明确清理逻辑（如 `MutationObserver` 单例） |
| `utils/` | 无状态纯工具函数 | 无副作用、不依赖组件上下文 |
| `locales/` | `locale/`（UI 文案）与 `error/`（错误文案）双轨，再按语种拆分 | — |
| `styles/` | `index.scss` 单入口分层引入 | 按变量覆写、组件覆写与通用样式分层引入 |

## 命名与编码约定

- 功能目录名 `camelCase`；路由 `path` 全小写拼接；实体身份通过路径参数 `/:id` 传递，不塞进 URL query（表单模式参数除外，由项目统一选定 `route.name` 或 `query.mode`）。
- 页面跳转优先使用具名路由 `router.push({ name, ... })`。
- 组件名与模板标签统一 `PascalCase`；`emits` 事件名统一 `kebab-case`；组件内属性顺序保持一致。
- 路由 `meta.i18nKey` 与 `menuList` 条目必须使用同一国际化键（共享 `route.<name>` 命名空间）。

## 路由、菜单与多标签历史

- `router/routes/index.ts`：维护 `path → 页面组件` 映射，路由 `meta` 承载 `title`、`icon`、`i18nKey`、`noTab`。
- `router/menu/menuList.ts`：独立菜单配置表，一个菜单项可聚合多个关联路由；菜单不反向充当路由身份源。
- 路由守卫：根路径 `/` 默认跳向首个可用菜单路由；`afterEach` 更新当前激活路由并同步菜单高亮（支持前缀匹配与回退）。
- 开发调试隔离：demo 页、开发调试路由和菜单放在独立文件，统一通过 `import.meta.env.DEV` 条件注入，生产构建中不包含任何开发路由。
- `HistoryTabs`（假标签页）：仅记录访问路径不缓存页面组件（不配合 `keep-alive`）；表单/详情页通过 `meta.noTab` 排除；记录条数设上限（如 20 条 FIFO），通过 `sessionStorage` 持久化，支持拖拽排序。

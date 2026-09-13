# 目录结构 canon

## 主分界规则

业务事实按种类集中（apis/types/stores/locales/hooks/utils/styles）；页面 UI 按业务共置（views/children/<feature>/ 收页面 + 私有组件 + 私有 svg + 私有类型）。

判断口诀：删掉这层 UI 还成立 → 集中；跟着页面生死 → 共置。

既有例外：跨页共享 API 类型集中在 types/apis；组件私有 svg 跟组件走；单一后端域可在 apis/ 下建子树（如 apis/park-group-service/ 含自己的类型）。

## views/children/<feature>/ 形态

- `<Feature>.vue` 主页面 + `index.ts` 唯一门口（`export { default } from './<Feature>.vue'`）
- 私有组件 / xxxForm.vue / xxxDetail.vue / xxxTab.vue 同目录共置
- 私有 svg/、私有 types.ts 按需同目录
- 路由懒加载经门口：`() => import('@/views/children/<feature>')`；同 feature 子页面可直接 import .vue
- 命名后缀语义：Form（新建/编辑/详情表单）、Detail（详情）、Tab（页签内容）

## components 三区

| 区 | 装什么 | 判据 |
|---|---|---|
| components/（DM* 前缀） | 通用能力件：对组件库的二次封装（表格、分页表格、树、图表、按钮） | 剥掉业务还成立；可拷任意项目 |
| components/views/ | 跨页业务复用件（带接口业务：Login、PermissionTree、ImageUpload 类） | ≥2 页复用且带产品语义 |
| components/Workbench/ | 仪表盘 widget（QuickLogin、PendingApproval、AlarmCenter 类） | dashboard 专用小件 |

- DM/Dm 前缀只标能力件；业务件永不带（历史壳件如 Sidebar/Navbar 曾豁免，新代码从严）
- 页面私有件不进任何公共区；出现第二个调用方才升 components/views/
- 能力件判定：富文本、日期选择、通用下拉类即使当前单页使用，也要判一次「剥掉业务文案/接口还成立吗」

## 集中区职责

| 目录 | 职责 | 准入 |
|---|---|---|
| apis/ | 每端点一函数薄包装 | 无 loading/缓存/状态 |
| types/apis/ | 接口类型 | 跟 apis 域文件配对 |
| libs/ | HttpRequest、i18n 实例 | 基础设施 |
| stores/ | user/menu/history（Pinia） | 仅跨页导航/会话态；表单筛选弹窗态留页内 |
| hooks/ | 带生命周期行为（如 MutationObserver 单例） | 复用 ≥2 处或含清理逻辑 |
| utils/ | 无状态纯函数 | 无副作用 |
| locales/ | locale/ UI 文案 + error/ 错误文案，再分语言 | — |
| styles/ | index.scss 单入口分层 | 详见 engineering.md |

## 命名法典（源自 rules/base.md）

- 路由 path 全小写拼接；实体身份用 `/:id` 不用 query（表单模式判定不在此列，统一规则见 table-form.md）
- 路由跳转用具名路由 push
- 组件名 PascalCase；emits 事件名 kebab-case
- 属性顺序统一；表单文件用 xxxForm 命名
- 路由与 menuList 的 i18nKey 必须对齐（共享 `route.<name>` 命名空间）
- 不提交 lock/.vscode/dist

## 路由与菜单

- routes/index.ts：path → import 映射表（路由即地图）；meta 承载 title/icon/i18nKey/noTab
- menuList.ts：独立菜单表，可聚合多路由；不反向长出路由身份
- 首路由守卫：`/` → menuList[0]；afterEach 写 activeRoute + 同步菜单高亮（前缀匹配 + activeRoute 回退）
- dev 路由/菜单（devRoutes/devMenuList）用 import.meta.env.DEV 圈禁，生产表出厂即空
- HistoryTabs：记录路径不缓存页面；noTab meta 排除表单页；上限 20 FIFO；sessionStorage 持久

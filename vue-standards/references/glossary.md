# 名词表（glossary）

> 术语唯一权威表：正文以简称使用这些词，定义以本表为准；正文与本表冲突时以本表为准并回改正文。
> 本表自包含，不依赖通用规范 skill。

## 结构层

| 名词 | 定义 | 判定 / 例子 | 常见误读 |
|---|---|---|---|
| 主分界规则 | 业务事实按「种类」集中；页面 UI 按「业务」共置 | 口诀：删掉这层 UI 它还成立吗 | |
| 一页一门口 | 每个业务页（feature）住 `views/children/<feature>/`，经目录内 `index.ts` 暴露唯一入口；主页面懒加载走门口，同 feature 子页可直达 .vue | index.ts 只 `export { default } from './Xxx.vue'` | 误读：apis/stores 也要 index——**从不设 barrel**；误读二：门口写成多行转发 |
| DM 前缀 | 「对第三方基础库（Element Plus、ECharts 等）二次封装的**能力件**」标记（DMTable 封 el-table、DMChart 封 ECharts）；**业务件永不带**；壳件与简单卡片豁免（Sidebar/StatCard 无前缀属存量历史不一致，不扩展；**新代码能力件一律带**） | 前缀=能力信号，不是品牌装饰 | 误读：所有通用组件都必须 DM 开头 |
| 三区 | `components/`=通用能力件（零业务）；`components/views/`=跨页**业务**复用件（带接口业务）；`components/Workbench/`=仪表盘 widget 特区 | Login/PermissionTree 在 views/，QuickLogin/AlarmCenter 在 Workbench/ | 误读：Workbench 是页面——它是 widget 挂件特区 |
| 能力件 / 业务件 | 能力件=剥掉业务文案与接口仍成立（富文本/日期选择）；业务件=绑产品语义（筛选列表/本域字段） | 口诀：去掉这个域的文案和接口，它还成立吗 | |
| 抽取时机 | 第二调用方出现才进 components/views/；能力件单页使用也要判一次可移植性 | 页面私有组件默认共置在 feature 目录 | 「以后可能复用」不构成抽取理由 |
| 分职（路由/菜单） | `router/routes/`=path→import 身份地图；`router/menu/`=菜单表，**可聚合多路由**（一个菜单项指向多个路由路径） | 菜单不产生第二路由身份 | |
| DEV 圈禁 | demo 页、dev 路由、dev 菜单全部 `import.meta.env.DEV` 条件注入；生产路由/菜单表出厂即空 | devRoutes/devMenuList 独立文件 | demo 混进生产构建=违约 |
| 命名法 | 文件夹 camelCase；路由 path 全小写拼接；组件名 PascalCase；语义后缀 Form/Detail/Tab；路径参数 `/:id` 不用 query | xxxForm.vue / BasicInfoTab.vue | |

## 代码内部层

| 名词 | 定义 | 例子 / 要点 | 常见误读 |
|---|---|---|---|
| 双信封 | mock 走 `{code,message,data}`，真实后端走 `{retCode,msg,data}`；拦截层以 **retCode 缺省直通**区分两轨 | dev mock 与真实后端同一套请求代码切换 | ≠ 两套 axios |
| 三级回退 | 码表(值为 i18n **key** 名) → 原始 msg（可能本身就是机器码）→ UNKNOWN 兜底 | `1_01_02` 型三段码；{count} 由响应 data 填充 | 误读：码表值是中文文案——是 i18n 键名 |
| 列表页五件套 | ①searchForm+pageInfo 组件局部 ②query() 先 `pageNumber=1` 再查 ③统一 changePage(num,size) ④try/finally 手动 loading ⑤重置=逐字段+页1+重查 | dateRange→ISO 在组装参数时转换（边界归一化一次） | |
| 薄封装（表格） | DMTable 只标准化**列声明**（tableHead）与**插槽路由**（slot:{name} / slots:[{slot,name}]）；不拥有 loading/空态/分页数据 | `v-bind="$attrs"` 透传；页面自己 v-loading | 误读：DMTable 内部管 loading——没有 |
| 透明 expose | `vm.exposed = exposed` 运行时替换自身暴露面，父 ref 直调底层 el-table 方法 | DMTable/DMPageTable/DMTree 系统性使用 | |
| 分页合流 | size-change + current-change → 单一 `change-page(pageNum,pageSize)` emit | pagination ref 故意不暴露 | |
| 一表单多模式 | 新增/编辑/详情共用一个 xxxForm.vue，靠路由分模式（判定入口统一=**项目内**单一入口：route.name 或 query.mode 选一种后全项目固定，法典不规定选哪种；query.id 禁止新增） | 详情态 Footer 隐藏、字段禁用 | 已知漂移：历史存在四种判定写法，新代码必须收敛为一种 |
| 字段级禁用矩阵 | `:disabled="isDetail || workStatus==='离职'"`——字段级、可叠加业务态 | | 表单级 disabled 覆盖不了叠加 |
| Dialog 状态机 | dialogVisible+dialogType；destroy-on-close 杀 DOM/校验态，**reactive 模型手工重置**；编辑只拷贝字段；`:before-close` 统一草稿清理 | 成功→关闭+query() 回页 1 | |
| 三通道通信 | props 下发 + emits 上抛 + ref 实例方法；**零 provide/inject、零事件总线、零 defineModel** | 多 v-model= 手写 computed get/set 代理（'update:xxx'） | |
| 状态准入 | stores/ 只收跨页会话态（user/menu/history）；表单/筛选/弹窗态留页内 | sessionStorage JSON try/catch 恢复 | |
| 无 keep-alive（假 tab） | HistoryTabs 记录**路径**不缓存页面态；切回列表必然新数据 | sessionStorage 上限 20、可拖拽排序、noTab 路由排除 | 误读：keep-alive 忘了开——是刻意不用 |
| 焦土式登出 | `sessionStorage.clear()` 清整个会话存储——新增缓存键自动被覆盖，免维护清单 | | |
| TableLayout 四槽 | Search / Action / ActionRight / default(表格区)，零脚本——搜索↔表格协议是**页面内闭包**（searchForm+query()），不是组件间通信 | `@keyup.enter` 触发 query | |
| FormLayout 四槽 | Header / TopRight / default(表单体) / Footer（详情态隐藏） | | |
| MainLayout 壳 | 唯一全局 chrome（Sidebar/Navbar/HistoryTabs/AppMain）；登录页在壳外 | | 每页自编结构=违约 |
| route i18nKey 对齐 | 路由 meta.i18nKey 与 menuList 条目必须同键（文档链接门禁校验对象之一） | `route.<name>` 命名空间 | |

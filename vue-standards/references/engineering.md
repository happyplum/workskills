# 工程化 canon（lint/提交/样式/构建/mock/i18n）

## 脚手架

新工程克隆 E:\lzy\myProject\cli\vue-vite-cli；其 rules/（base.md/dev.md/git.md）+ dev.vue（可运行规范）为法典。生产是权威源：定期「同步 XX」式反向萃取进模板。

## Lint 链

- run-s：oxlint（快扫）→ eslint（兜底）→ lint-staged
- script-setup 写法 ESLint 强制（vue/component-api-style: ['script-setup']）
- apis/mock 目录 any 放宽；风格只归格式器管

## 提交与分支

- commitlint 自定义 [type] 解析器（9 类）；header ≤100
- 分支 <type>/<基线>-<缩写>-<描述>；rebase 流；同主题 >5 commit squash
- pre-commit：ts:check + lint-staged

## 样式

- styles/ 单入口分层：index.scss → eleTheme（--el-* 变量覆写）→ element/（结构性覆写）→ layout → card → table → font
- 页面样式：不写 scoped、顶层类 BEM 命名、≤3 层嵌套、不用 !important、element 内部用 :deep
- 运行时主题：主色经 colorjs.io 派生 light-3/5/7/8/9 + dark-2 梯度写 documentElement CSS 变量；localStorage 存 topColor/sideColor；useWhiteBg 模块级单例 MutationObserver 联动
- 图标四策略：静态 img / new URL(..., import.meta.url) 动态 / import.meta.glob ?raw + v-html（currentColor）/ SVG-as-Vue 组件

## Element Plus 按需三层

- unplugin-vue-components ElementPlusResolver（模板 kebab 自动）
- 脚本手动 import（ElMessage 等）
- unplugin-element-plus 样式按需；手写 import 的组件需手动补样式（已知坑：DMPageTable 补 el-pagination.css）
- ElConfigProvider locale 随 i18n 同步

## mock / i18n

- vite-plugin-mock；mock 信封必须与真实信封对齐（历史坑：code:200 vs retCode 不一致）
- i18n：legacy:false；locale/（UI 文案）+ error/（错误文案）双命名空间再分语言；localStorage + navigator 检测；路由与菜单共享 route.<name> 键

## 构建

- rolldown-vite（实验性 Rust 构建器，口味接受）
- git 信息注入：__GIT_INFO__ define（commit/branch/时间等 7 字段）+ window.showBuildInfo() 控制台表格
- 代理即路径：后端路径 = 前端路径，按服务前缀分流，零 rewrite（如 /park- → 后端）
- manualChunks 外部私有包（@haplum/config chunkChunk）

## 已知漂移与未收口（新代码必须修正；转项目规范时逐项裁决）

1. 提交 loading 历史只有 2/20 表单有——新表单必带
2. 模式判定多种写法并存（route.name 三元 / path.includes / query.id / 组合式）——统一到 table-form.md 声明的单一入口
3. rules 文案语言混用（i18n / 硬编码中文 / 英文）——统一走 i18n
4. rules/dev.md 禁 scoped/!important 与实践相悖（DM* 用 scoped+#anchor、UploadDialog 有 !important）——裁决后统一
5. 模板 WIP 残留：HistoryTabs merge 标记入库、counter.ts/App.spec 脚手架遗留、Navbar 重复声明、ThemeConfigDrawer undefined 引用、types/apis 声称未建、reset+refetch 演示缺失——清理
6. catch 后 tableData 清理漂移（有的清有的不清）——定一条统一
7. 测试腐烂（App.spec 断言已重写的 App）——删除或重写

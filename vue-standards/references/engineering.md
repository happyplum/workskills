# Vue 工程化与工具链规范

## Lint 与代码检查链

- 串联顺序：`oxlint`（极速基础扫描）→ `eslint`（Vue 与项目深度规则兜底）→ `lint-staged`（提交前只检改动文件）。
- ESLint 显式强制 `<script setup>` 写法（`vue/component-api-style: ['script-setup']`）。
- 仅在接口声明或 Mock 数据目录适度放宽 `any` 约束；代码排版风格统一交给 formatter，不和 ESLint 规则打架。

## 提交与分支习惯

- 配合 `commitlint` 校验统一提交信息格式，控制单行 header 长度（如 ≤100 字符）。
- 特性分支采用规范命名（如 `<type>/<基线>-<简述>`），优先线性 rebase 流，合并前压缩过多细碎提交。
- `pre-commit` 钩子运行类型检查（`ts:check`）与 `lint-staged`。

## 样式、主题与图标

- **全局样式单入口分层**：`styles/index.scss` 按顺序引入变量覆写（`--el-*`）→ 组件库结构覆写（`element/`）→ `layout` → `card` → `table` → `font`，避免覆盖顺序失控。
- **页面样式约束**：统一约定顶层容器类 BEM 命名、嵌套不超过 3 层、尽量不用 `!important`、穿透组件库内部样式使用 `:deep()`（项目内对是否使用 `scoped` 保持统一口径，不一半用一半不用）。
- **运行时主题派生**：基于主色通过 `colorjs.io` 动态派生亮/暗色阶（如 `light-3/5/7/8/9`、`dark-2`）写入 `documentElement` CSS 变量；用户主题偏好存 `localStorage`；需要感知根主题变化时可用模块级单例 `MutationObserver` 联动。
- **图标按需选策略**：静态图片用 `<img>`，动态路径用 `new URL(..., import.meta.url)`，需要 `currentColor` 跟随主题变色的 SVG 用 `import.meta.glob(..., { query: '?raw' })` 或封装为 Vue 组件。

## Element Plus 按需引入三层注意点

1. **模板组件**：通过 `unplugin-vue-components` + `ElementPlusResolver` 自动按需引入。
2. **脚本调用组件**：`ElMessage`、`ElMessageBox`、`ElNotification` 等在 JS/TS 里手动 `import`。
3. **按需样式补齐**：使用 `unplugin-element-plus` 自动引入样式；**已知易踩坑**：通过 `h()` 或脚本手动引入且未在模板直接书写的组件（如动态渲染的分页组件），需要确认其对应 CSS 已显式引入，否则样式会丢失。
4. 使用 `ElConfigProvider` 让 Element Plus 组件语言与 `vue-i18n` 保持同步。

## Mock 与国际化（i18n）

- **Mock**：使用 `vite-plugin-mock`；Mock 响应结构尽量与真实后端对齐，或在请求拦截层做好双格式兼容，避免联调阶段大面积改字段。
- **i18n**：启用 Composition API 模式（`legacy: false`）；`locales/` 拆分为 `locale/`（界面文案）和 `error/`（错误文案）两大命名空间再分语种；语言初始化优先读 `localStorage` 再回退浏览器 `navigator.language`；路由和菜单共享 `route.<name>` 键。

## 构建与开发代理

- **构建信息注入**：通过构建配置 `define` 注入 `__GIT_INFO__`（commit、branch、构建时间等），并在 `window` 挂一个调试函数（如 `window.showBuildInfo()`）以表格打印版本信息，线上排查省心高效。
- **开发代理零路径改写**：前端请求服务前缀与后端接口前缀对齐，按前缀直接转发，不做复杂 `rewrite`。
- **按需拆包**：大型第三方库或内部基础包通过 `manualChunks` 合理拆分，控制首屏体积。

## 落地与评审时的常见一致性检查

新项目初始化或老项目代码评审时，重点核对以下容易漂移的细节：

1. **表单提交 loading**：所有新增/编辑提交按钮都应带 `try / finally` 控制的 loading，不能漏掉。
2. **表单模式判定唯一**：全项目只留一种模式判定方式（`route.name` 或 `query.mode` 二选一），清理掉混用的旧写法。
3. **校验文案统一走 i18n**：表单 rules 里的提示文案不混写硬编码中文与英文，统一接入多语言。
4. **样式隔离口径一致**：`scoped` 与 `!important` 的使用规则在基础组件和业务页面间口径清晰，规范与实际代码不打架。
5. **列表接口异常后的展示策略统一**：明确 `catch` 后是否保留旧表格数据还是清空列表，全项目统一处理（优先参考界面稳定性原则：首次加载失败显式展示失败态，刷新失败尽量保留有效旧数据并提示）。

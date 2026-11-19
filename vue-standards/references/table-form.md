# Vue 表格、表单、弹窗与图表封装规范

> 以下用 `Base*` 示意项目统一约定的基础封装组件前缀（各项目可按自身习惯命名，如 `AppTable`、`UiTable` 等；核心是保持前缀统一且**业务组件绝不复用该前缀**）。

## 薄封装表格（`BaseTable`）

- **声明式列配置**：通过 `tableHead`（列配置数组）、`tableData`、`autoHeight`、`tableId`、`showColumnConfig` 驱动渲染。
- **自定义单元格插槽按名扩展**：支持单插槽（如 `slot: { name }`）与多插槽（如 `slots: [{ slot: 'header' | 'default', name }]`）在列配置里声明位置，外部按名提供插槽内容，表格组件本身零改动即可扩展任意自定义列。
- **薄封装，不抢页面职责**：通过 `v-bind="$attrs"` 透传原生属性与事件；**不持有** `loading`、空态、分页状态和数据请求逻辑，由页面通过 `v-loading="tableLoading"` 等方式自行传入。
- **透传底层表格实例方法**：通过 `vm.exposed = exposed` 将底层 `el-table` 实例方法直接透出，父组件通过 `ref` 即可调用原生方法，无需逐个手写包装。
- **列显示配置持久化**：按 `tableId` 将列可见性与拖拽顺序存入 `localStorage`（如 `table-${tableId}-columns`）；`fixed` 与 `type` 功能列不参与排序；列唯一标识优先取 `prop`，缺失时用 `label` 兜底。

## 分页表格组合（`BasePageTable`）

- 将分页组件的 `size-change` 与 `current-change` 合流为单一事件：`change-page(pageNum, pageSize)`。
- 使用渲染函数 `h(BaseTable, { ...attrs, ref }, slots)` 组合，保持插槽和属性完全透传。
- 刻意只向外透出底层表格实例，不暴露内部分页组件 `ref`。

## 列头筛选组件（`BaseTableHeaderFilter`）

- 筛选变更事件直接同步回页面的 `searchForm` 并调用 `query()`。
- 多选模式采用「草稿编辑 + 点击确认生效」，关闭弹窗未确认时还原原值；单选模式选择即立即生效。

## 页面布局容器

- **`MainLayout`**：唯一全局外壳（侧栏 / 顶栏 / 历史标签栏 / 主内容区），登录页及独立全屏页放在外壳之外。
- **`TableLayout`**：零脚本纯样式四插槽容器（`Search` / `Action` / `ActionRight` / `default` 表格区）。搜索区与表格区联动直接走页面内闭包（共享 `searchForm` 和 `query()`），不额外造跨组件通信桥。
- **`FormLayout`**：四插槽容器（`Header` / `TopRight` / `default` 表单体 / `Footer`），详情模式下 `v-if` 隐藏 `Footer`，`TopRight` 可放返回与切换编辑入口。
- 布局容器按页面内容形态选用，支持合理嵌套（例如左侧树 + 右侧 `TableLayout`）。

## 表单与弹窗约定

- **一表单多模式**：新增、编辑、详情共用同一个 `xxxForm.vue`。项目内必须统一选择 `route.name` 或 `query.mode` **其中一种**作为模式判断入口并全项目固定，禁止混用多种写法（不要靠是否存在 `query.id` 推断模式）。
- **字段级禁用支持业务态叠加**：禁用写在字段级（`:disabled="isDetailMode || <业务态条件>"`），避免表单级整体禁用无法表达「部分字段按业务状态禁用」的矩阵。
- **校验规则就地编写**：规则用 `reactive` 直接写在表单组件内，方便跨字段校验通过闭包读取其他字段；多卡片表单共享一份表单数据模型、按区分别挂 `ElForm` 并用 `Promise.all` 联合校验；触发时机默认输入 `blur`、选择 `change`。
- **弹窗状态机与彻底清理**：
  - 使用 `dialogVisible` + `dialogType` 管理显示与模式，弹窗开启 `destroy-on-close` 销毁 DOM 和校验状态；
  - `destroy-on-close` 不会重置 Vue 响应式数据，关闭或打开前必须**手动重置表单数据模型**；
  - 进入编辑态时浅拷贝所需字段，避免直接修改表格行原对象；
  - 右上角关闭、点击遮罩和点击取消统一通过 `:before-close` 清理草稿状态。
- **提交保护与刷新**：提交按钮必带 `try / finally` 托管的提交 loading；提交成功后关闭弹窗并调用列表 `query()` 回到第 1 页刷新。
- **弹窗调用方式**：页面局部弹窗默认用 `v-model` 控制；全局单例弹窗（如全局设置抽屉、过期提示弹窗）可用 `defineExpose({ open })` 提供命令式入口。

## 图表双层封装

- **基础图表层（`BaseChart`）**：专注 ECharts 生命周期管理（`init` / `resize` / `dispose` + 深度监听 option 变化时调用 `setOption(opt, true)`），仅对外 `expose` 必要的 `resize()` 方法。
- **业务图表层（`BaseLineChart` / `BaseBarChart` / `BasePieChart`）**：内置常用默认视觉配置，通过 `deepMerge(defaultOption, props.option)` 合并，调用方传入的配置始终优先。

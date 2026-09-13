# 表格/表单/弹窗/图表 canon

## DMTable（薄封装）

- props：tableHead（列配置数组）/ tableData / autoHeight / tableId / showColumnConfig
- 列配置声明式：每项 v-bind 透传；自定义单元格双协议——`slot:{name}` 单插槽 / `slots:[{slot:'header'|'default', name}]` 多插槽（位置在配置里声明，封装层零改动支持扩展）
- v-bind="$attrs" 透传：loading/选择/空态由页面给（v-loading 统一用 tableLoading 命名）
- 不拥有：loading、空态、分页、数据获取
- 透明 expose：vm.exposed = exposed——父 ref 直接调底层表格方法
- 列配置持久化：localStorage `dmtable-${tableId}-columns`（可见性 + 顺序，Sortable 拖拽；fixed/type 列不参与）；列 ID = prop || label 兜底

## DMPageTable

- change-page(pageNum, pageSize) 单一 emit（尺寸/页码合流）
- 分页 ref 刻意不透出（canon 注释：「暂时就穿透个表格出去」）
- h(DMTable, {...$attrs, ref}, $slots) 渲染函数组合

## 布局协议

- MainLayout：唯一全局壳（Sidebar/Navbar/HistoryTabs/AppMain）；登录页在壳外
- TableLayout（零脚本 4 slots）：Search / Action / ActionRight / default——搜索↔表格协议 = 页面闭包（searchForm + query()），不抽通信组件
- FormLayout（3 slots + Footer）：Header / TopRight / default + Footer（详情模式 v-if 隐藏）；详情页兼任编辑入口（TopRight 返回 + 编辑）
- 布局按内容形状选用，可嵌套（如 树+表格复合布局 > TableLayout）

## DMTableHeaderFilter

- 列头筛选桥：@change → searchForm + query()
- multiple 模式草稿-确认（关闭还原 modelValue）；single 立即生效

## 表单协议

- 一表单多模式：新增/编辑/详情共用；**模式判定入口统一为 `route.name` 或 `query.mode` 二选一**（项目内选定一种后固定）；历史 `query.id` 写法列为待收敛漂移，禁止新增使用
- 禁用矩阵：字段级 `:disabled="isDetailMode || <业务态>"`
- rules 就地内联 reactive（跨字段校验闭包引用需要）；多卡表单共享一个 model、按 ElForm 分组规则；Promise.all 联合校验；trigger：输入 blur / 选择 change
- Dialog 状态机：dialogVisible + dialogType + destroy-on-close；model 手工重置；编辑只拷贝字段防污染；:before-close 统一 X/遮罩/取消的草稿清理
- 提交：try/finally + 按钮 loading（历史缺口，新代码必补）；成功 → 关闭 + query() 回页 1
- 弹窗默认局部 v-model；全局单例弹窗用 defineExpose({open}) 命令式（如 LicenseExpireDialog/ThemeConfigDrawer）

## 图表双层

- DMChart：生命周期 owner（init/resize/dispose + deep-watch setOption notMerge=true + 仅 expose resize）
- DMLine/Bar/PieChart：deepMerge(默认, props.option)——consumer wins

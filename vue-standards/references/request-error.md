# 请求层与数据流 canon

## HttpRequest（libs/HttpRequest.ts）

- 单例 axios 包装；自定义 Token header（从 user store 读）
- 双信封桥：真实后端 {retCode,msg,data}；mock {code,message,data}——`retCode === undefined` 直通区分两轨
- errorCode = res.msg || String(retCode)：msg 字段兼做机器码
- 三级回退：codeMap[i18n key] → res.msg → UNKNOWN_ERROR；ElMessage 提示 5s
- 业务成功判定 retCode === 1；HTTP 层错误统一 SERVICE_ERROR
- LOGOUT_CODES 常量（登出码数组）+ 完整登出分支——机制先行，码值按后端补
- 拦截器内惰性 useUserStore()（规避 pinia 初始化顺序与循环依赖）
- timeout 显式设定；不做自动重试/去重（保持管道零状态）

## codeMap（utils/error/codeMap.ts）

- 键：'模块_子域_序号' 三段码（如 '1_01_02'）
- 值：i18n 键名（不是文案本身）
- `ErrorCode = keyof typeof codeMap` 类型收窄
- getErrorMessage(code, params?) 支持 {count} 插值——参数来自响应 data（remainingAttempts/accountLockRemainMinutes）

## apis/ 薄包装

- 每端点导出一个函数；入参/返回接 types/apis 类型
- pageSize/pageNumber 分页约定；函数名 post<Domain><Action> 风格
- codegen 子树（如 park-group-service/）机械命名 + 端到端类型，是唯一全链路类型真源
- 不建 service 层、不做 loading/缓存

## 列表页五件套（同构强制）

1. searchForm + pageInfo 组件内 reactive（不进 store）
2. `query() { pageNumber = 1; getData() }`
3. changePage(pageNum, pageSize) 统一处理
4. try/finally 包 getData 管 tableLoading
5. reset：逐字段还原 + query()

- dateRange → ISO 在组装参数时转一次（边界归一化）
- getData() 在 setup 顶层直接调用（不等 onMounted）
- 搜索输入 @keyup.enter="query"

## 会话与多租户

- token/user 存 sessionStorage（JSON + try/catch 恢复）；与标签页同生共死
- 登出焦土式：sessionStorage.clear() + 跳登录——新增缓存自动被覆盖，免清理清单
- 多租户切分：身份租户（groupId/loginGroupId）进凭证；数据范围（parkId）进各页查询参数，不全局注入
- 密码摘要：MD5×10 链式 + 小写用户名盐（前后端算法契约）

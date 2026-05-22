# 外部模型审查示例

使用**混合输出**方法（聊天摘要 + 文件包）的真实示例。

---

## 示例 1：架构审查

### 背景

计划从单体架构迁移到微服务架构。对服务边界和数据一致性策略存在不确定性。

### 聊天摘要输出

```markdown
## 📤 外部审查就绪

**审查目标：**
验证单体到微服务的迁移计划，关注服务边界正确性和数据一致性风险。

**关注领域：**
- 服务分解策略
- 分布式事务处理
- 数据所有权边界

**审查包：**
`C:\Projects\ecommerce-refactor\external-review-request.md`

**操作说明：**
1. 打开上述文件（或复制其全部内容）
2. 粘贴到 Gemini、Codex 或 Claude
3. 将 JSON 响应粘贴回此处

**可选包装提示词：**
> Review the following markdown packet. Follow the "Required Output" section exactly. Analysis only. No implementation. No code patches.

---
```

### 文件内容（external-review-request.md）

```markdown
# External Review Request

## Reviewer Rules
- Analysis only. No implementation. No code patches.
- If context is incomplete, state assumptions clearly.

## Review Objective
Review the migration plan from monolith to microservices, focusing on service boundaries and data consistency.

## Questions To Answer
1. Are the proposed service boundaries aligned with domain boundaries?
2. How should Order-Inventory transactions be handled?
3. What data ownership patterns should be established?

## Scope
### In Scope
- Service decomposition
- Data consistency strategy
- Inter-service communication

### Out of Scope
- Infrastructure provisioning
- CI/CD pipeline changes

## Repository Context
- **Repo:** ecommerce-platform
- **Relevant Area:** Order processing, Inventory management
- **Current State:** Monolith handling 2000 RPM, 95th percentile 120ms
- **Constraints:** Zero downtime migration required

## Material Manifest
| Type | Path | Why It Matters |
|------|------|----------------|
| Plan | `plans/migration/plan.md` | Migration strategy |
| Research | `docs/ddd-analysis.md` | Bounded context mapping |
| Evidence | `logs/performance-baseline.txt` | Current system metrics |

## Plan Summary
- Decompose into User, Order, Inventory, Payment services
- Use event-driven architecture for inter-service communication
- Implement API Gateway for client requests
- Database-per-service pattern

## Evidence
### Key Findings
- Order service depends on Inventory for stock checks
- No saga pattern defined for Order-Inventory flow
- Product catalog accessed by multiple services

## Required Output
[JSON schema as defined in template.md]
```

### 外部模型 JSON 响应

```json
{
  "reviewer": {
    "model": "Gemini-2.0-Flash",
    "review_type": "architecture",
    "confidence": "high",
    "date": "2026-03-18"
  },
  "summary": {
    "verdict": "needs_revision",
    "score": 65,
    "one_sentence_rationale": "Service boundaries are reasonable but distributed transaction strategy is missing."
  },
  "issues": [
    {
      "id": "I1",
      "severity": "critical",
      "title": "Saga Pattern Missing",
      "path": "plans/migration/plan.md",
      "evidence": "Order-Inventory interaction has no distributed transaction strategy",
      "why_it_matters": "Data inconsistency during partial failures",
      "recommended_change": "Implement orchestrated saga with compensating actions"
    },
    {
      "id": "I2",
      "severity": "critical",
      "title": "Data Ownership Ambiguity",
      "path": "plans/migration/plan.md",
      "evidence": "Product catalog accessed by both Order and Inventory services",
      "why_it_matters": "Coupling through shared database undermines service independence",
      "recommended_change": "Establish clear data ownership (Inventory owns catalog)"
    }
  ],
  "open_questions": [
    "What is the acceptable latency for cross-service calls?",
    "How will you handle schema evolution across services?"
  ],
  "assumptions": [
    "Assuming PostgreSQL for all services",
    "Assuming synchronous communication is acceptable for stock checks"
  ]
}
```

### 集成步骤

1. **应用怀疑协议**：验证问题在实际计划中确实存在
2. **提议 `[External]` 任务**：
   - `[External-CRITICAL]` 为 Order-Inventory 流程实现 saga 模式
   - `[External-CRITICAL]` 将产品目录所有权重构至 Inventory 服务
3. **用户审批**：「外部审查发现 2 个关键架构缺口。是否更新计划？」

---

## 示例 2：安全审计

### 背景

使用 JWT 令牌和刷新令牌轮换重新设计认证系统。

### 聊天摘要输出

```markdown
## 📤 外部审查就绪

**审查目标：**
对基于 JWT 的认证重新设计进行安全审计，关注令牌处理漏洞。

**关注领域：**
- 令牌存储和传输
- 会话管理
- 攻击向量（XSS、CSRF、重放）

**审查包：**
`C:\Projects\auth-service\external-review-request.md`

**操作说明：**
1. 打开上述文件（或复制其全部内容）
2. 粘贴到 Gemini、Codex 或 Claude
3. 将 JSON 响应粘贴回此处

---
```

### 外部模型 JSON 响应

```json
{
  "reviewer": {
    "model": "Claude-3.5-Sonnet",
    "review_type": "security",
    "confidence": "high",
    "date": "2026-03-18"
  },
  "summary": {
    "verdict": "block",
    "score": 40,
    "one_sentence_rationale": "Critical security vulnerabilities in token storage and binding must be fixed before implementation."
  },
  "issues": [
    {
      "id": "I1",
      "severity": "critical",
      "title": "Refresh Token in localStorage",
      "path": "src/auth/token-service.ts",
      "evidence": "Plan stores refresh tokens in localStorage",
      "why_it_matters": "XSS vulnerability exposes long-lived credentials",
      "recommended_change": "Use httpOnly cookies for refresh tokens"
    },
    {
      "id": "I2",
      "severity": "critical",
      "title": "Missing Token Binding",
      "path": "src/auth/token-service.ts",
      "evidence": "JWTs not bound to device/session",
      "why_it_matters": "Token theft allows replay from any device",
      "recommended_change": "Include device fingerprint in JWT claims"
    },
    {
      "id": "I3",
      "severity": "major",
      "title": "No Secret Rotation Plan",
      "path": "plans/auth-redesign/plan.md",
      "evidence": "No mention of JWT secret rotation",
      "why_it_matters": "Compromised secret invalidates all sessions",
      "recommended_change": "Implement key rotation with grace period"
    }
  ],
  "open_questions": [
    "What is the acceptable user friction for re-authentication?"
  ],
  "assumptions": []
}
```

### 怀疑协议应用

| 问题 | 已验证？ | 备注 |
|------|----------|------|
| I1：localStorage | ✅ 是 | 在 token-service.ts 第 45 行确认 |
| I2：令牌绑定 | ✅ 是 | JWT 载荷中无指纹 |
| I3：密钥轮换 | ⚠️ 部分 | 计划提及轮换但缺乏细节 |

### 集成步骤

1. **验证**：确认问题存在于代码/计划中
2. **提议 `[External]` 任务**：
   - `[External-CRITICAL]` 将刷新令牌存储迁移至 httpOnly cookies
   - `[External-CRITICAL]` 在 JWT claims 中添加设备指纹
   - `[External-MAJOR]` 设计 JWT 密钥轮换机制
3. **用户审批**：「安全审计发现 3 个问题（2 个关键）。是否进行修复？」

---

## 示例 3：怀疑协议实战

### 背景

外部审查者**低信心**建议进行重大架构变更。

### 外部模型 JSON 响应

```json
{
  "reviewer": {
    "model": "Gemini-2.0-Flash",
    "review_type": "architecture",
    "confidence": "low",
    "date": "2026-03-18"
  },
  "summary": {
    "verdict": "needs_revision",
    "score": 55,
    "one_sentence_rationale": "Consider rewriting the entire auth module using a different framework."
  },
  "issues": [
    {
      "id": "I1",
      "severity": "critical",
      "title": "Rewrite Auth Module",
      "path": "src/auth/",
      "evidence": "Current implementation is not optimal",
      "why_it_matters": "Better long-term maintainability",
      "recommended_change": "Rewrite using OAuth2 provider library"
    }
  ],
  "assumptions": [
    "Assuming current implementation has no tests",
    "Assuming team has OAuth2 expertise"
  ]
}
```

### 怀疑协议触发

**🚨 检测到红旗：**
- 审查者信心**低**
- 建议**不成比例**（因「不够优化」而重写整个模块）
- 假设可能**不正确**（项目有测试，团队无 OAuth2 专业知识）

**代理响应：**
```
⚠️ 怀疑协议警报

外部审查存在红旗：
1. 低信心（55%）
2. 不成比例的建议（因「不够优化」而重写整个模块）
3. 不正确的假设（项目有测试，团队缺乏 OAuth2 专业知识）

应用前请确认：
- 您是否已验证当前认证实现存在根本性缺陷？
- 完全重写是否与发现的问题成比例？
- 团队是否具备 OAuth2 专业知识来采用此方案？

建议请求第二意见或要求审查者基于正确假设重新澄清。
```

---

## 常见模式

### 请求构建
- 聊天摘要：目标 + 关注领域 + 文件路径 + 说明
- 文件包：精炼内容、仓库相对路径、JSON 输出模式

### 响应处理
- 解析 JSON 响应
- 应用怀疑协议
- 将问题转换为 `[External]` 前缀任务
- 等待用户确认

### 怀疑触发条件
- 低信心分数
- 不成比例的建议
- 不正确的假设
- 不存在的文件路径
- 与代码库模式矛盾

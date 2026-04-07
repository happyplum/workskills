# External Model Review Examples

Real-world examples using the **hybrid output** approach (chat summary + file packet).

---

## Example 1: Architecture Review

### Context
Planning a migration from monolithic to microservices architecture. Uncertain about service boundaries and data consistency strategy.

### Chat Summary Output

```markdown
## 📤 External Review Ready

**Review Goal:**
Validate the monolith-to-microservices migration plan for service boundary correctness and data consistency risks.

**Focus Areas:**
- Service decomposition strategy
- Distributed transaction handling
- Data ownership boundaries

**Review Packet:**
`C:\Projects\ecommerce-refactor\external-review-request.md`

**Instructions:**
1. Open the file above (or copy its full contents)
2. Paste into Gemini, Codex, or Claude
3. Paste the JSON response back here

**Optional Wrapper Prompt:**
> Review the following markdown packet. Follow the "Required Output" section exactly. Analysis only. No implementation. No code patches.

---
*File size: ~85 lines | Generated: 2026-03-18*
```

### File Content (external-review-request.md)

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

### External Model JSON Response

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

### Integration Steps

1. **Apply Skepticism Protocol**: Verify issues exist in actual plan
2. **Propose `[External]` Tasks**:
   - `[External-CRITICAL]` Implement saga pattern for Order-Inventory flow
   - `[External-CRITICAL]` Refactor product catalog ownership to Inventory service
3. **User Approval**: "External review found 2 critical architecture gaps. Update plan?"

---

## Example 2: Security Audit

### Context
Redesigning authentication system with JWT tokens and refresh token rotation.

### Chat Summary Output

```markdown
## 📤 External Review Ready

**Review Goal:**
Security audit of the JWT-based authentication redesign for token handling vulnerabilities.

**Focus Areas:**
- Token storage and transmission
- Session management
- Attack vectors (XSS, CSRF, replay)

**Review Packet:**
`C:\Projects\auth-service\external-review-request.md`

**Instructions:**
1. Open the file above (or copy its full contents)
2. Paste into Gemini, Codex, or Claude
3. Paste the JSON response back here

---
*File size: ~72 lines | Generated: 2026-03-18*
```

### External Model JSON Response

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

### Skepticism Protocol Applied

| Issue | Verified? | Notes |
|-------|-----------|-------|
| I1: localStorage | ✅ Yes | Confirmed in token-service.ts line 45 |
| I2: Token binding | ✅ Yes | No fingerprint in JWT payload |
| I3: Secret rotation | ⚠️ Partial | Plan mentions rotation but lacks details |

### Integration Steps

1. **Validate**: Confirmed issues exist in code/plan
2. **Propose `[External]` Tasks**:
   - `[External-CRITICAL]` Migrate refresh token storage to httpOnly cookies
   - `[External-CRITICAL]` Add device fingerprint to JWT claims
   - `[External-MAJOR]` Design JWT secret rotation mechanism
3. **User Approval**: "Security audit found 3 issues (2 critical). Proceed with fixes?"

---

## Example 3: Skepticism Protocol in Action

### Context
External reviewer with **low confidence** suggested major architectural changes.

### External Model JSON Response

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

### Skepticism Protocol Triggered

**🚨 Red Flags Detected:**
- Reviewer confidence is **low**
- Recommendation is **disproportionate** (rewrite entire module)
- Assumptions may be **incorrect** (team does have tests, no OAuth2 expertise)

**Agent Response:**
```
⚠️ Skepticism Protocol Alert

The external review has red flags:
1. Low confidence (55%)
2. Disproportionate recommendation (rewrite entire module for "not optimal")
3. Incorrect assumptions (project has tests, team lacks OAuth2 expertise)

Before applying, please confirm:
- Have you verified the current auth implementation is fundamentally flawed?
- Is a full rewrite proportional to the issues found?
- Does the team have OAuth2 expertise for this approach?

I recommend requesting a second opinion or asking the reviewer to clarify with correct assumptions.
```

---

## Common Patterns

### Request Construction
- Chat summary: Goal + Focus areas + File path + Instructions
- File packet: Refined content, repo-relative paths, JSON output schema

### Response Processing
- Parse JSON response
- Apply Skepticism Protocol
- Convert issues to `[External]` prefixed tasks
- Wait for user confirmation

### Skepticism Triggers
- Low confidence score
- Disproportionate recommendations
- Incorrect assumptions
- Non-existent file paths
- Contradictions with codebase patterns

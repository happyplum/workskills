---
name: omo-subagent-type
description: "Use when calling task() to route work. Covers subagent_type selection, category selection, run_in_background, and load_skills configuration."
---

# omo-subagent-type

Use this skill before ANY `task()` call. It ensures valid schema, correct routing, and prompts subagents can execute.

## 0. Quick Start

**One rule:** `task()` requires exactly one of `subagent_type` XOR `category`, plus `run_in_background`, `load_skills`, `description`, and `prompt`.

### Escalation Ladder

**Category cost order (default low→high):** direct tools → `quick` → `unspecified-low` → `unspecified-high` → `deep` → `ultrabrain`. Domain categories (`visual-engineering`, `artistry`, `writing`) override cost tiers — see Q4.

Only escalate when lower-cost tiers are clearly insufficient.

### Decision Questions (answer in order)

```
Q1: Is file location known AND task is single-step (no discovery)?
    → YES: Use direct tools (read/grep/glob/edit). STOP.
    → NO: Continue to Q2.

Q2: Is the task primarily about this repo/worktree artifacts (code, docs, config, scripts)?
    → YES: Continue to Q3.
    → NO: What is the main need?
        - Retrieval (docs, examples, API reference) → subagent_type="librarian", run_in_background=true. STOP.
        - Reasoning/clarification → Continue to Q3.

Q3: What is the task type?
    → Search/discover patterns → subagent_type="explore", run_in_background=true
    → Clarify ambiguous request or critique/review → route to appropriate review agent, run_in_background=false
        - completion-status / omission check → `metis` first
        - post-`metis` deep review / plan-revision guidance → `oracle`
    → Architecture/debug or explicit escalation → route to appropriate escalation agent, run_in_background=false
    → Implement code → Continue to Q4.

Q4 (Implementation — domain categories override cost tiers):
    a) UI/UX/styling work (includes refactors, builds, large-scale UI) → category="visual-engineering"
    b) Non-conventional creative design → category="artistry"
    c) Documentation/prose → category="writing"
    d) Bounded, pattern-known (≤2 files, no architecture tradeoff) → category="quick"
    e) Multi-file, routine implementation → category="unspecified-low"
    f) Significant scope with moderate uncertainty → category="unspecified-high"
    g) Broad uncertainty + iterative discovery loops → category="deep"
    h) Hard reasoning (algorithms, formal tradeoffs, complex state machines) → category="ultrabrain"
    → Fallback (none match): category="unspecified-high"
```

### Minimal Valid Call

```typescript
task({
  subagent_type: "explore",  // XOR category
  run_in_background: true,
  load_skills: [],
  description: "Short summary",
  prompt: "[CONTEXT]: ...\n[GOAL]: ...\n[RETURN]: ..."
})
```

**Prompt fields:** `[CONTEXT]` (situation), `[GOAL]` (what to achieve), `[RETURN]` (expected output format) — required. Add `[SCOPE]`/`[SKIP]`/`[WHY_NOT_LOWER_COST]`/`[INPUT-ORIGINAL]` only when needed.

---

## 1. Core Contract (MUST — 7 rules)

**Violating any of these causes task() to fail or produce garbage output.**

| # | Rule | Verification |
|---|------|--------------|
| 1 | **XOR:** Provide `subagent_type` OR `category`, never both | Schema check |
| 2 | **Required:** `run_in_background`, `load_skills`, `description`, `prompt` | Schema check |
| 3 | **Background:** `explore`/`librarian` = true; review/escalation agents/category = false | Agent type check |
| 4 | **Skills:** Only use skills from your `available_skills` list; verify exact name; default `[]` unless task clearly matches a skill's trigger | Cross-check system list |
| 5 | **Prompt:** Must include `[CONTEXT]`, `[GOAL]`, `[RETURN]` | Field presence |
| 6 | **Language:** Prompt body in English; quote original non-English input via `[INPUT-ORIGINAL]` | LLM instruction |
| 7 | **Async:** Wait for system reminder before `background_output()`; never poll running task | Call sequence |

---

## 2. Agent & Category Guide

This table is a scoped routing guide for the common subagent choices this skill standardizes. It is not intended to be an exhaustive catalog of every system-available agent.

### Subagent Types

| Agent | When | Output |
|-------|------|--------|
| `explore` | Internal codebase search, pattern discovery | File paths + pattern summaries |
| `librarian` | External docs, OSS examples, API correctness | URLs + quoted excerpts |
| `metis` | Ambiguous request, need plan before coding, critique/review, Final Verification Wave reviewer, completion-status gap finding | Clarified requirements + omission review |
| `oracle` | Architecture tradeoffs, debugging, explicit escalation, post-`metis` deep review, plan-revision guidance | Decision + reasoning + revision brief |
| `momus` | Plan review (when explicitly requested) | Pass/fail + fixes |

### Cost Guardrails

- Do **not** choose `deep` when the task is mostly deterministic with known patterns.
- Do **not** choose `ultrabrain` unless there is explicit hard-logic evidence.
- If undecided between `quick` and `deep`, choose `unspecified-low` first.
- For verification-only work (assertions, logs, simple checks), default to `quick`.
- **MUST:** When selecting `deep` or `ultrabrain`, include `[WHY_NOT_LOWER_COST]` in prompt. *(Verification: field presence)*

### Plan-Execution Verification Exception

For Task N-V verification tasks: match the parent task's domain category. Downgrade to `quick` if verification is only CLI/log/assertion work. Use `visual-engineering` for UI/playwright/screenshot validation. Include evidence destination and success gate in the delegation prompt. *(Verification: prompt contains evidence destination + success gate)*

---

## 3. Failure Protocol

### When Delegation Fails

1. **Read the error** — Schema validation? Fix args. Subagent failure? Retry with more context.
2. **Add context** — Expand prompt sections before retry.
3. **Max 2 retries** — After 2 failures with same approach, switch strategy:
   - `explore` failed → Try `librarian` for external docs
   - `category` failed → Try review agent to clarify requirements first
4. **Escalate** — After 3 total failures, escalate or ask user.
5. **Async discipline** — `run_in_background=true`: do NOT plan dependent follow-up until system reminder arrives.

### Prohibited Behaviors

| ❌ Prohibited | Why |
|---------------|-----|
| `task(subagent_type=..., category=..., ...)` | XOR violation, schema error |
| `task(load_skills=["magic-skill"], ...)` | Invented skill, load error |
| `run_in_background=true` then immediate `background_output()` | Polling running task, blocks forever |
| Missing `[RETURN]` in prompt | Subagent produces unstructured garbage |
| Silent retry without adding context | Repeats same failure |
| Infinite agent chaining (A→B→C→D...) | Context dilution, no progress |
| Skipping `background_output()` after async task | Wasted work, no result |
| Mixing search + implement in one delegation | Subagent overwhelmed |

---

## 4. Appendix

### Good Examples

**Explore (internal search):**
```typescript
task({
  subagent_type: "explore",
  run_in_background: true,
  load_skills: [],
  description: "Find auth middleware patterns",
  prompt: "[CONTEXT]: Adding JWT auth to REST API.\n[GOAL]: Find existing auth middleware and token flow.\n[SCOPE]: src/api/ and src/middleware/\n[SKIP]: test files\n[RETURN]: File paths + brief pattern description"
})
```

**Librarian (external docs):**
```typescript
task({
  subagent_type: "librarian",
  run_in_background: true,
  load_skills: [],
  description: "Find Fastify JWT plugin best practices",
  prompt: "[CONTEXT]: Building JWT auth with Fastify, need production patterns.\n[GOAL]: Find @fastify/jwt usage examples, token refresh patterns, and security recommendations.\n[SKIP]: Basic 'what is JWT' tutorials.\n[RETURN]: Code snippets + best practice summary"
})
```

**Category (deep — with justification):**
```typescript
task({
  category: "deep",
  run_in_background: false,
  load_skills: [],
  description: "Untangle unknown legacy dispatch",
  prompt: "[CONTEXT]: Dispatch path spans unknown modules with conflicting behavior.\n[GOAL]: Map flow and implement stable routing.\n[WHY_NOT_LOWER_COST]: Requires iterative discover-and-fix across uncertain interactions.\n[RETURN]: Flow map + final patch"
})
```

### Bad Example

```typescript
// ❌ WRONG: Using explore for known file
task({
  subagent_type: "explore",
  run_in_background: true,
  load_skills: [],
  description: "Read tsconfig",
  prompt: "[GOAL]: Read tsconfig.json content"
})

// ✅ CORRECT: Direct tool
read({ filePath: "/absolute/path/to/tsconfig.json" })
```

**Remember:** Subagents don't share your conversation context. Every missing parameter forces them to guess. Explicit = reliable.
